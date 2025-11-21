SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWAVPK07                                         */
/* Creation Date: 14-MAR-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-6437 CN Converse B2B PTS Precartonization               */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 14-Jul-2020  NJOW01   1.0  Rollback WMS-11438                        */
/************************************************************************/

--[isp_CreatePickdetail_WIP] MR

CREATE PROC [dbo].[ispWAVPK07]   
   @c_Wavekey   NVARCHAR(10),  
   @b_Success   INT      OUTPUT,
   @n_Err       INT      OUTPUT, 
   @c_ErrMsg    NVARCHAR(250) OUTPUT  
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_SourceType                   NVARCHAR(30),
           @c_Storerkey                    NVARCHAR(15),
           @c_Sku                          NVARCHAR(20),
           @c_UOM                          NVARCHAR(10),
           @n_Casecnt                      INT,
           @n_SplitQty                     INT,
           @c_NewPickdetailKey             NVARCHAR(10),
   	       @n_DropID_Seq_Prefix            INT,
           @n_DropID_Seq_Wave              INT,
           @n_PLTID_Seq_Prefix             INT,
           @n_PLTID_Seq_Wave               INT,
           @n_DropIdCnt                    INT,
           @n_StyleColorCnt                INT,
           @n_TotalDropId                  INT,
           @c_ResetDropIdCnt               NCHAR(1),
           @c_PalletID                     NVARCHAR(20),
           @c_Orderkey                     NVARCHAR(10),
           @c_DropID                       NVARCHAR(20),
           @c_Notes                        NVARCHAR(50),
           @n_PltNoMixOrderMinCartonCnt    INT,
           @n_MaxFullCntPerPallet          INT,
           @c_SQL                          NVARCHAR(MAX),
           @n_Range1_Min                   INT,
           @n_Range1_Max                   INT,
           @n_Range2_Min                   INT,
           @n_Range2_Max                   INT,
           @n_Range3_Min                   INT,
           @n_Range3_Max                   INT,
           @n_Range4_Min                   INT,
           @n_Range4_Max                   INT,
           @n_Range1_MaxPltStyleColor      INT,
           @n_Range2_MaxPltStyleColor      INT,
           @n_Range3_MaxPltStyleColor      INT,
           @n_Range4_MaxPltStyleColor      INT,
           @c_Style                        NVARCHAR(20), 
           @c_Color                        NVARCHAR(10), 
           @n_MaxPltStyleColor             INT,
           @n_PrevMaxPltStyleColor         INT,
           @n_TotalPickQty                 INT,
           @n_DropIDQtyCanFit              INT,
           @c_LocationCategory             NVARCHAR(10),
           @c_Pickdetailkey                NVARCHAR(10),
           @n_PickQty                      INT,
           @c_DropIDPrefix                 NVARCHAR(10),
           @c_PalletPrefix                 NVARCHAR(10)
                                               
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT
   
 	 IF @n_err =  1
	    SET @n_debug = 1
	 ELSE
	    SET @n_debug = 0		 
                                                     
	SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1 
	
  SET @n_DropID_Seq_Wave = 0
  SET @n_PLTID_Seq_Wave = 0
  SET @c_DropIDPrefix = 'DID'
  SET @c_PalletPrefix = 'PID'

  SET @c_SourceType = 'ispWAVPK07'    

	 IF @@TRANCOUNT = 0
	    BEGIN TRAN
      
   --Create temporary table
   IF @n_continue IN(1,2)
   BEGIN    
      CREATE TABLE #PickDetail_WIP(
      	[PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
      	[CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[PickHeaderKey] [nvarchar](18) NOT NULL,
      	[OrderKey] [nvarchar](10) NOT NULL,
      	[OrderLineNumber] [nvarchar](5) NOT NULL,
      	[Lot] [nvarchar](10) NOT NULL,
      	[Storerkey] [nvarchar](15) NOT NULL,
      	[Sku] [nvarchar](20) NOT NULL,
      	[AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[UOMQty] [int] NOT NULL DEFAULT ((0)),
      	[Qty] [int] NOT NULL DEFAULT ((0)),
      	[QtyMoved] [int] NOT NULL DEFAULT ((0)),
      	[Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
      	[DropID] [nvarchar](20) NOT NULL DEFAULT (''),
      	[Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
      	[ID] [nvarchar](18) NOT NULL DEFAULT (' '),
      	[PackKey] [nvarchar](10) NULL DEFAULT (' '),
      	[UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
      	[CartonGroup] [nvarchar](10) NULL,
      	[CartonType] [nvarchar](10) NULL,
      	[ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
      	[DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
      	[ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
      	[DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
      	[PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
      	[WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[EditDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[TrafficCop] [nvarchar](1) NULL,
      	[ArchiveCop] [nvarchar](1) NULL,
      	[OptimizeCop] [nvarchar](1) NULL,
      	[ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
      	[PickSlipNo] [nvarchar](10) NULL,
      	[TaskDetailKey] [nvarchar](10) NULL,
      	[TaskManagerReasonKey] [nvarchar](10) NULL,
      	[Notes] [nvarchar](4000) NULL,
      	[MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
      	[WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
        [Channel_ID] [bigint] NULL DEFAULT ((0)))	         

        CREATE INDEX PDWIP_OrderLN ON #PickDetail_WIP (Orderkey, OrderLineNumber)          
        CREATE INDEX PDWIP_sKU ON #PickDetail_WIP (Storerkey, Sku)    
   END
   
   --Validation            
   IF @n_continue IN(1,2) 
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                JOIN  WAVEDETAIL WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey 
                WHERE PD.Status='4' AND PD.Qty > 0 
                AND  WD.Wavekey = @c_WaveKey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END

      IF EXISTS (SELECT 1
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey   
                 JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
                 WHERE WD.Wavekey = @c_Wavekey
                 AND PD.Notes <> ''
                 AND PD.Notes IS NOT NULL
                 AND PD.DropID <> ''
                 AND PD.DropID IS NOT NULL
                 AND PD.Status >= 3)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized. Not allow to run again. (ispWAVPK07)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
   END
   
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
           @c_Loadkey               = ''
          ,@c_Wavekey               = @c_wavekey  
          ,@c_WIP_RefNo             = @c_SourceType 
          ,@c_PickCondition_SQL     = ''
          ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
          ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
          ,@b_Success               = @b_Success OUTPUT
          ,@n_Err                   = @n_Err     OUTPUT 
          ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
          
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END          
      BEGIN
         UPDATE #PickDetail_WIP SET DropID = '', Notes = ''
      END
   END   
    
   --Assign drop id to full case(2), conso case(6) and loose case(7) 
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_PICKGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory, SUM(PD.Qty)
         FROM #PickDetail_WIP PD 
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         AND ISNULL(PD.DropId,'') = ''
         GROUP BY PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory
         ORDER BY PD.UOM, LOC.LocationCategory, PD.Sku
      
      OPEN CUR_PICKGROUP  
       
      FETCH NEXT FROM CUR_PICKGROUP INTO @c_Storerkey, @c_Sku, @c_UOM, @n_CaseCnt, @c_LocationCategory, @n_TotalPickQty
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN
      	 IF @c_UOM = '7'
      	 BEGIN
       	    SET @n_DropIDQtyCanFit = @n_TotalPickQty

         	  EXEC dbo.nspg_GetKey                
                @KeyName = 'CONVDROPID'    
               ,@fieldlength = 10    
               ,@keystring = @c_DropID OUTPUT    
               ,@b_Success = @b_success OUTPUT    
               ,@n_err = @n_err OUTPUT    
               ,@c_errmsg = @c_errmsg OUTPUT
               ,@b_resultset = 0    
               ,@n_batch     = 1                  
               
            SET @c_DropID = RTRIM(ISNULL(@c_DropIDPrefix,'')) + @c_DropID           	          	    
       	 END
       	 ELSE   
      	    SET @n_DropIDQtyCanFit = 0
      	 
      	 DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      	    SELECT PD.Pickdetailkey, PD.Qty
      	    FROM #PickDetail_WIP PD 
      	    JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      	    WHERE PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
      	    AND PD.UOM = @c_UOM
      	    AND LOC.LocationCategory = @c_LocationCategory
      	    AND ISNULL(PD.Dropid,'') = ''
      	    ORDER BY PD.Loc
      	 
      	 OPEN CUR_PICK  
       
         FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PickQty

         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
         BEGIN         	
         	  WHILE @n_PickQty > 0 AND @n_continue IN(1,2)         
         	  BEGIN
         	  	 IF @n_DropIDQtyCanFit <= 0 AND @c_UOM IN('2','6')
         	     BEGIN
         	     	 SET @n_DropIDQtyCanFit = @n_CaseCnt
         	     	 
         	     	 EXEC dbo.nspg_GetKey                
                      @KeyName = 'CONVDROPID'    
                     ,@fieldlength = 10    
                     ,@keystring = @c_DropID OUTPUT    
                     ,@b_Success = @b_success OUTPUT    
                     ,@n_err = @n_err OUTPUT    
                     ,@c_errmsg = @c_errmsg OUTPUT
                     ,@b_resultset = 0    
                     ,@n_batch     = 1                  
                     
                  SET @c_DropID = RTRIM(ISNULL(@c_DropIDPrefix,'')) + @c_DropID             	    	 
         	     END
         	     
         	     IF @n_DropIDQtyCanFit >= @n_pickQty
         	     BEGIN
                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET DropID =  @c_DropID
                  WHERE Pickdetailkey = @c_Pickdetailkey                  
                  
                  SELECT @n_DropIDQtyCanFit = @n_DropIDQtyCanFit - @n_pickQty
                  SELECT @n_PickQty = 0
         	     END
         	     ELSE
         	     BEGIN
                  SELECT @n_SplitQty = @n_PickQty - @n_DropIDQtyCanFit
                 
                  EXECUTE nspg_GetKey      
                     'PICKDETAILKEY',      
                     10,      
                     @c_NewPickdetailKey OUTPUT,         
                     @b_success OUTPUT,      
                     @n_err OUTPUT,      
                     @c_errmsg OUTPUT      
                  
                  IF NOT @b_success = 1      
                  BEGIN
                     SELECT @n_continue = 3      
                  END                  
                 
                  INSERT INTO #PickDetail_WIP 
                             (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, 
                              Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status],         
                              DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,      
                              ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,           
                              WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo,            
                              TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno)               
                   SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                          Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                          '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                          ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                          WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                          TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, @c_SourceType                                                           
                   FROM #PickDetail_WIP (NOLOCK)                                                                                             
                   WHERE PickdetailKey = @c_PickdetailKey         
                              
                   SELECT @n_err = @@ERROR
                   
                   IF @n_err <> 0     
                   BEGIN     
                      SELECT @n_continue = 3      
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030   
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK07)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                      --BREAK    
                   END
               
             	     UPDATE #PickDetail_WIP WITH (ROWLOCK) 
                   SET DropID = @c_DropID,
                       UOMQTY = CASE UOM WHEN '6' THEN @n_DropIDQtyCanFit ELSE UOMQty END, 
                       Qty = @n_DropIDQtyCanFit 
                   WHERE Pickdetailkey = @c_PickdetailKey
                                                                                                           
                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0 
                   BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040   
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK07)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                      --BREAK
                   END
                   
                   SELECT @n_PickQty = @n_PickQty - @n_DropIDQtyCanFit
                   SELECT @n_DropIDQtyCanFit = 0
                   SET @c_Pickdetailkey = @c_NewPickDetailkey --continue assigin drop id to the new pickdetail
         	     END         	             	    
         	  END

            FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PickQty         	
         END
         CLOSE CUR_PICK
         DEALLOCATE CUR_PICK

         FETCH NEXT FROM CUR_PICKGROUP INTO @c_Storerkey, @c_Sku, @c_UOM, @n_CaseCnt, @c_LocationCategory, @n_TotalPickQty
      END
      CLOSE CUR_PICKGROUP
      DEALLOCATE CUR_PICKGROUP                           
   END
    
   --Assign pallet to full carton (uom 2)
   IF @n_continue IN(1,2)
   BEGIN   	  
      SET @n_DropID_Seq_Prefix = 0
      SET @n_PLTID_Seq_Prefix = 0
      sET @n_DropIdCnt = 0     
      SET @c_ResetDropIdCnt = 'N'
      SET @n_PltNoMixOrderMinCartonCnt = 16
      SET @n_MaxFullCntPerPallet = 20
                 
      SET @c_SQL = N'DECLARE CUR_FULLCASE CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT PD.Orderkey, COUNT(DISTINCT PD.DropID)
         FROM #PickDetail_WIP PD         
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku        
         WHERE PD.UOM = ''2''
         GROUP BY PD.Orderkey ' +
       ' ORDER BY CASE WHEN COUNT(DISTINCT PD.DropID) >= ' + CAST(@n_PltNoMixOrderMinCartonCnt AS NVARCHAR) + ' THEN 1 ELSE 2 END, MIN(SKU.Style), MIN(SKU.Color), PD.Orderkey'
         
      EXEC sp_executesql @c_SQL
      
      OPEN CUR_FULLCASE  
       
      FETCH NEXT FROM CUR_FULLCASE INTO @c_Orderkey, @n_TotalDropID
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	 
      	 IF @c_ResetDropIdCnt = 'Y'
      	    SET @n_DropIdCnt = 0
         	           	 
      	 IF @n_TotalDropID >= @n_PltNoMixOrderMinCartonCnt  --The pallet no mix other order
      	 BEGIN
           	SET @c_ResetDropIdCnt = 'Y'  --Next order open new pallet
      	    SET @n_DropIdCnt = 0         --New pallet for current order
         END
         ELSE
           	SET @c_ResetDropIdCnt = 'N'  --Next order share open pallet
      	 
         DECLARE CUR_FULLCASE_DROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.DropID
            FROM #PickDetail_WIP PD
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            WHERE PD.Orderkey = @c_Orderkey
            AND PD.UOM = '2'
            GROUP BY PD.DropID
            ORDER BY MIN(SKU.Style), MIN(SKU.Color), PD.DropID

         OPEN CUR_FULLCASE_DROPID  
        
         FETCH NEXT FROM CUR_FULLCASE_DROPID INTO @c_DropID
   
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
         BEGIN      	          	  
         	  IF @n_DropIdCnt = 0
         	  BEGIN
              EXEC dbo.nspg_GetKey                
                @KeyName = 'CONVPLTID'    
               ,@fieldlength = 10    
               ,@keystring = @c_PalletID OUTPUT    
               ,@b_Success = @b_success OUTPUT    
               ,@n_err = @n_err OUTPUT    
               ,@c_errmsg = @c_errmsg OUTPUT
               ,@b_resultset = 0    
               ,@n_batch     = 1                  
	  	
	  	         SET @c_PalletId = RTRIM(ISNULL(@c_PalletPrefix,'')) + @c_PalletID
	  	         SET @n_PLTID_Seq_Prefix = @n_PLTID_Seq_Prefix +  1
               SET @n_PLTID_Seq_Wave = @n_PLTID_Seq_Wave + 1
            END

         	  SET @n_DropID_seq_Prefix = @n_DropID_seq_Prefix + 1
         	  SET @n_DropID_seq_Wave = @n_DropID_seq_Wave + 1	  
         	  SET @n_DropIDCnt = @n_DropIdCnt + 1
         	  
         	  IF @n_DropIdCnt >= @n_MaxFullCntPerPallet
         	     SET @n_DropIdcnt = 0         	  
         	              	     
         	  SET @c_Notes = 'A-' + CAST(@n_DropID_seq_Wave AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Wave AS NVARCHAR) + '-' + CAST(@n_DropID_seq_Prefix AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Prefix AS NVARCHAR)  + '-' + @c_PalletId
         	     
         	  UPDATE #PickDetail_WIP 
         	  SET Notes = @c_Notes   
         	  WHERE DropId = @c_DropID         	           	  
         	  
            FETCH NEXT FROM CUR_FULLCASE_DROPID INTO @c_DropID
         END
         CLOSE CUR_FULLCASE_DROPID
         DEALLOCATE CUR_FULLCASE_DROPID
                                  	 
         FETCH NEXT FROM CUR_FULLCASE INTO @c_Orderkey, @n_TotalDropID
      END
      CLOSE CUR_FULLCASE
      DEALLOCATE CUR_FULLCASE                          
   END

   --Assign pallet to loose/conso carton (uom 6 & 7)
   IF @n_continue IN(1,2)
   BEGIN   	  
      SET @n_DropID_Seq_Prefix = 0
      SET @n_PLTID_Seq_Prefix = 0
      sET @n_DropIdCnt = 0     
      SET @n_StyleColorCnt = 0
      SET @n_PrevMaxPltStyleColor = 0
      SET @n_MaxFullCntPerPallet = 20
      sET @n_Range1_Min = 1
      SET @n_Range1_Max = 5       
      SET @n_Range1_MaxPltStyleColor = 4
      sET @n_Range2_Min = 6
      SET @n_Range2_Max = 10
      SET @n_Range3_MaxPltStyleColor = 2
      sET @n_Range3_Min = 11
      SET @n_Range3_Max = 24       
      SET @n_Range3_MaxPltStyleColor = 1
      sET @n_Range4_Min = 25
      SET @n_Range4_Max = 999       
      SET @n_Range4_MaxPltStyleColor = 1
                 
      SET @c_SQL = N'DECLARE CUR_LOOSECASE CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT SKU.Style, SKU.Color, COUNT(DISTINCT PD.DropID),
                CASE WHEN COUNT(DISTINCT PD.DropID) BETWEEN @n_Range1_min AND @n_Range1_max THEN @n_Range1_MaxPltStyleColor 
                     WHEN COUNT(DISTINCT PD.DropID) BETWEEN @n_Range2_min AND @n_Range2_max THEN @n_Range2_MaxPltStyleColor 
                     WHEN COUNT(DISTINCT PD.DropID) BETWEEN @n_Range3_min AND @n_Range3_max THEN @n_Range3_MaxPltStyleColor 
                     WHEN COUNT(DISTINCT PD.DropID) BETWEEN @n_Range4_min AND @n_Range4_max THEN @n_Range4_MaxPltStyleColor 
                ELSE 1    
                END AS MaxPltStyleColor              
         FROM #PickDetail_WIP PD         
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku        
         WHERE PD.UOM IN(''6'',''7'')
         GROUP BY SKU.Style, SKU.Color
         ORDER BY 4, SKU.Style DESC, SKU.Color DESC '
         
      EXEC sp_executesql @c_SQL,      
      N'@n_Range1_Min INT, @n_Range1_Max INT, @n_Range2_Min INT, @n_Range2_Max INT, @n_Range3_Min INT, @n_Range3_Max INT, @n_Range4_Min INT, @n_Range4_Max INT, 
        @n_Range1_MaxPltStyleColor INT, @n_Range2_MaxPltStyleColor INT, @n_Range3_MaxPltStyleColor INT, @n_Range4_MaxPltStyleColor INT', 
      @n_Range1_Min,
      @n_Range1_Max,
      @n_Range2_Min,
      @n_Range2_Max,
      @n_Range3_Min,
      @n_Range3_Max,
      @n_Range4_Min,
      @n_Range4_Max,
      @n_Range1_MaxPltStyleColor,
      @n_Range2_MaxPltStyleColor,
      @n_Range3_MaxPltStyleColor,
      @n_Range4_MaxPltStyleColor
      
      OPEN CUR_LOOSECASE  
       
      FETCH NEXT FROM CUR_LOOSECASE INTO @c_Style, @c_Color, @n_TotalDropID, @n_MaxPltStyleColor
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	 
      	 IF @n_MaxPltStyleColor <> @n_PrevMaxPltStyleColor 
      	    SET @n_DropIdCnt = 0
      	       	 
         DECLARE CUR_LOOSECASE_DROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT DISTINCT PD.DropID
            FROM #PickDetail_WIP PD
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            WHERE SKU.Style = @c_Style 
            AND SKU.Color = @c_Color
            AND PD.UOM IN('6','7')            
            ORDER BY PD.DropID

         OPEN CUR_LOOSECASE_DROPID  
        
         FETCH NEXT FROM CUR_LOOSECASE_DROPID INTO @c_DropID
   
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
         BEGIN      	          	  
         	  IF @n_DropIdCnt = 0
         	  BEGIN
              EXEC dbo.nspg_GetKey                
                @KeyName = 'CONVPLTID'    
               ,@fieldlength = 10    
               ,@keystring = @c_PalletID OUTPUT    
               ,@b_Success = @b_success OUTPUT    
               ,@n_err = @n_err OUTPUT    
               ,@c_errmsg = @c_errmsg OUTPUT
               ,@b_resultset = 0    
               ,@n_batch     = 1                  
	  	
	  	         SET @c_PalletId = RTRIM(ISNULL(@c_PalletPrefix,'')) + @c_PalletID
	  	         SET @n_PLTID_Seq_Prefix = @n_PLTID_Seq_Prefix +  1
               SET @n_PLTID_Seq_Wave = @n_PLTID_Seq_Wave + 1
               
               SET @n_StyleColorCnt = @n_MaxPltStyleColor
            END

         	  SET @n_DropID_seq_Prefix = @n_DropID_seq_Prefix + 1
         	  SET @n_DropID_seq_Wave = @n_DropID_seq_Wave + 1	  
         	  SET @n_DropIDCnt = @n_DropIdCnt + 1
         	           	  
         	  IF @n_DropIdCnt >= @n_MaxFullCntPerPallet
         	     SET @n_DropIdcnt = 0         	  
         	     
         	  SET @c_Notes = 'B-' + CAST(@n_DropID_seq_Wave AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Wave AS NVARCHAR) + '-' + CAST(@n_DropID_seq_Prefix AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Prefix AS NVARCHAR)  + '-' + @c_PalletId
         	     
         	  UPDATE #PickDetail_WIP 
         	  SET Notes = @c_Notes   
         	  WHERE DropId = @c_DropID         	           	  
         	  
            FETCH NEXT FROM CUR_LOOSECASE_DROPID INTO @c_DropID
         END
         CLOSE CUR_LOOSECASE_DROPID
         DEALLOCATE CUR_LOOSECASE_DROPID
         
         SET @n_StyleColorCnt = @n_StyleColorCnt - 1 
         SET @n_PrevMaxPltStyleColor = @n_MaxPltStyleColor
         
         IF @n_StyleColorCnt <= 0  --New pallet if max style color per pallet reach
            SET @n_DropIdcnt = 0
                                  	 
         FETCH NEXT FROM CUR_LOOSECASE INTO @c_Style, @c_Color, @n_TotalDropID, @n_MaxPltStyleColor
      END
      CLOSE CUR_LOOSECASE
      DEALLOCATE CUR_LOOSECASE                          
   END
         
   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN   	 
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_Wavekey 
           ,@c_WIP_RefNo             = @c_SourceType 
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT 
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
          
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END      
         
   QUIT_SP:

   IF OBJECT_ID('tempdb..#PickDetail_WIP','u') IS NOT NULL
      DROP TABLE #PickDetail_WIP
 
	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	 	IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		ROLLBACK TRAN
	 	END
	 	ELSE
	 	BEGIN
	 		WHILE @@TRANCOUNT > @n_StartTCnt
	 		BEGIN
	 			COMMIT TRAN
	 		END
	 	END
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK07'		
	 	RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	 	--RAISERROR @nErr @cErrmsg
	 	RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	 	WHILE @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		COMMIT TRAN
	 	END
	 	RETURN
	 END  	 	 
END

GO