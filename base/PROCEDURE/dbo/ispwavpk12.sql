SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWAVPK12                                         */
/* Creation Date: 16-SEP-2020                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-14744 CN Converse Precartonization                      */
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
/* 30-Nov-2011  NJOW01   1.0  WMS-18425 Wave type 2 with UOM 6,7 Stamp  */
/*                            sequence no  to notes. 4 carton per seq#  */
/* 30-Nov-2021  NJOW01   1.1  DEVOPS combine script                     */
/* 07-Sep-2022  WLChooi  1.2  JSM-94336 - Insert ChannelID (WL01)       */
/************************************************************************/
CREATE PROC [dbo].[ispWAVPK12]   
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
           @n_TotalDropId                  INT,
           @c_ResetDropIdCnt               NCHAR(1),
           @c_PalletID                     NVARCHAR(20),
           @c_DropID                       NVARCHAR(20),
           @c_Notes                        NVARCHAR(50),
           @n_PltNoMixLoadMinCartonCnt     INT,
           @n_PltNoMixSkuMinCartonCnt      INT,
           @n_MaxFullCntPerPallet          INT,
           @n_TotalPickQty                 INT,
           @n_DropIDQtyCanFit              INT,
           @c_LocationCategory             NVARCHAR(10),
           @c_Pickdetailkey                NVARCHAR(10),
           @n_PickQty                      INT,
           @c_DropIDPrefix                 NVARCHAR(10),
           @c_PalletPrefix                 NVARCHAR(10),           
           @c_WaveType                     NVARCHAR(18),
           @c_Loadkey                      NVARCHAR(10),
           @n_MaxPltLoad                   INT,
           @n_MaxPltSKU                    INT,
           @n_PrevMaxPltLoad               INT,         
           @n_SharePltIdCnt                INT,
           @n_Loadcnt                      INT,
           @n_SkuCnt                       INT,
           @n_SeqNo                        INT,
           @n_CurrSeqQty                   INT,
           @c_Facility                     NVARCHAR(5),
           @c_WaveType2LooseAssignPlt      NVARCHAR(10)
                                               
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

  SET @c_SourceType = 'ispWAVPK12'    

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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized. Not allow to run again. (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
   END
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  SELECT TOP 1 @c_WaveType = W.WaveType,
   	               @c_Storerkey = O.Storerkey,
   	               @c_Facility = O.Facility
   	  FROM WAVE W(NOLOCK)
   	  JOIN WAVEDETAIL WD (NOLOCK) ON W.Wavekey = WD.Wavekey
   	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	  WHERE W.Wavekey = @c_Wavekey
   	  
   	  --NJOW01
   	  SELECT @c_WaveType2LooseAssignPlt = dbo.fnc_GetParamValueFromString('@c_WaveType2LooseAssignPlt', SC.Option5, '')
   	  FROM dbo.fnc_getright2(@c_Facility, @c_Storerkey,'','WAVGENPACKFROMPICKED_SP') AS SC
   	  WHERE SC.Authority = 'ispWAVPK12'
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
   	  IF @c_WaveType = '1'
   	  BEGIN
         DECLARE CUR_PICKGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory, SUM(PD.Qty)
            FROM #PickDetail_WIP PD 
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            AND ISNULL(PD.DropId,'') = ''
            AND PD.Uom = '2'  --conso load ctn
            GROUP BY PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory
            ORDER BY PD.UOM, LOC.LocationCategory, PD.Sku                              
      END   
      ELSE
      BEGIN  --2
         DECLARE CUR_PICKGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory, SUM(PD.Qty)
            FROM #PickDetail_WIP PD 
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
            AND ISNULL(PD.DropId,'') = ''
            AND PD.Uom IN('2','6','7')   --Full order ctn,conso wave cnt,loose
            GROUP BY PD.Storerkey, PD.Sku, PD.UOM, PACK.CaseCnt, LOC.LocationCategory
            ORDER BY PD.UOM, LOC.LocationCategory, PD.Sku                              
      END
            
      OPEN CUR_PICKGROUP  
       
      FETCH NEXT FROM CUR_PICKGROUP INTO @c_Storerkey, @c_Sku, @c_UOM, @n_CaseCnt, @c_LocationCategory, @n_TotalPickQty
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN
      	 IF @c_UOM = '7'
      	 BEGIN
       	    SET @n_DropIDQtyCanFit = @n_TotalPickQty   --same sku to one dropid

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
                              TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno, Channel_ID)   --WL01               
                   SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                          Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                          '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                          ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                          WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                          TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, @c_SourceType, Channel_ID   --WL01                                                           
                   FROM #PickDetail_WIP (NOLOCK)                                                                                             
                   WHERE PickdetailKey = @c_PickdetailKey         
                              
                   SELECT @n_err = @@ERROR
                   
                   IF @n_err <> 0     
                   BEGIN     
                      SELECT @n_continue = 3      
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030   
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
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
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
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
      SET @n_PltNoMixLoadMinCartonCnt = 13
      SET @n_MaxFullCntPerPallet = 24
      SET @n_PrevMaxPltLoad = 0 
      
      SELECT LPD.Loadkey, COUNT(DISTINCT PD.DropID) AS TotalDropID, 
             CASE WHEN COUNT(DISTINCT PD.DropID) >= @n_PltNoMixLoadMinCartonCnt THEN 1
                  WHEN COUNT(DISTINCT PD.DropID) >= 7 AND COUNT(DISTINCT PD.DropID) < @n_PltNoMixLoadMinCartonCnt THEN 2
                  ELSE 4 END AS MaxPltLoad,
             MAX(LA.Lottable01) AS Lottable01                  
      INTO #TMP_LOAD
      FROM #PickDetail_WIP PD         
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku        
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot         
      WHERE PD.UOM = '2'
      GROUP BY LPD.Loadkey

      SELECT MaxPltLoad, MAX(Lottable01) AS Lottable01
      INTO #TMP_LOADGRP
      FROM #TMP_LOAD
      GROUP BY MaxPltLoad  
            
      DECLARE CUR_FULLCASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT L.Loadkey, L.TotalDropID, L.MaxPltLoad
         FROM #TMP_LOAD L
         JOIN #TMP_LOADGRP LG ON L.MaxPltload = LG.MaxPltLoad
         ORDER BY L.MaxPltLoad, L.TotalDropID, L.Loadkey
         --ORDER BY LG.Lottable01 DESC, L.MaxPltLoad, L.TotalDropID, L.Loadkey
                     
      OPEN CUR_FULLCASE  
       
      FETCH NEXT FROM CUR_FULLCASE INTO @c_Loadkey, @n_TotalDropID, @n_MaxPltLoad
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	 
      	 SET @n_SharePltIdCnt = 0  
      	 
      	 IF @c_ResetDropIdCnt = 'Y'
      	    SET @n_DropIdCnt = 0
      	       	 
      	 IF @n_PrevMaxPltLoad <> @n_MaxPltLoad
      	    SET @n_DropIdCnt = 0  --new pallet
         	           	 
      	 IF @n_MaxPltLoad = 1 --The pallet no mix other load
      	 BEGIN      	 	
           	SET @c_ResetDropIdCnt = 'Y'  --Next order open new pallet
      	    SET @n_DropIdCnt = 0         --New pallet for current order
      	    SET @n_SharePltIdCnt = 1     --share same pallet id for the load
         END
         ELSE
           	SET @c_ResetDropIdCnt = 'N'  --Next load share open pallet
      	 
         DECLARE CUR_FULLCASE_DROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT PD.DropID
            FROM #PickDetail_WIP PD
            JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            WHERE LPD.Loadkey = @c_Loadkey
            AND PD.UOM = '2'
            GROUP BY PD.DropID
            ORDER BY MIN(SKU.Style), MIN(SKU.Color), PD.DropID

         OPEN CUR_FULLCASE_DROPID  
        
         FETCH NEXT FROM CUR_FULLCASE_DROPID INTO @c_DropID
   
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
         BEGIN      	          	  
         	  IF @n_DropIdCnt = 0 
         	  BEGIN
         	  	IF @n_SharePltIdCnt <= 1  -- 0=no share or 1=first pallet. 2nd share onward use share pallet id
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
                 SET @n_Loadcnt = @n_MaxPltLoad 
              END
             
              IF @n_SharePltIdCnt > 0  
                 SET @n_SharePltIdCnt = @n_SharePltIdCnt + 1	  	
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

         SET @n_Loadcnt = @n_Loadcnt - 1
         
         --open new pallet for next load and not to mix with current share pallet
         IF @n_SharePltIdCnt > 0 OR @n_Loadcnt <= 0 
            SET @n_DropIdcnt = 0                       
                  
         SET @n_PrevMaxPltLoad = @n_MaxPltLoad 
                                  	 
         FETCH NEXT FROM CUR_FULLCASE INTO @c_Loadkey, @n_TotalDropID, @n_MaxPltLoad
      END
      CLOSE CUR_FULLCASE
      DEALLOCATE CUR_FULLCASE                          
   END   

   --Assign pallet to loose/conso carton (uom 6 & 7)
   IF @n_continue IN(1,2) AND @c_Wavetype = '2'
      AND ISNULL(@c_WaveType2LooseAssignPlt,'') = 'Y'  --NJOW01
   BEGIN   	  
      SET @n_DropID_Seq_Prefix = 0
      SET @n_PLTID_Seq_Prefix = 0
      SET @n_DropIdCnt = 0     
      SET @c_ResetDropIdCnt = 'N'      
      SET @n_MaxFullCntPerPallet = 24
      SET @n_PltNoMixSkuMinCartonCnt = 15      
      SET @n_MaxPltSKU = 4
                 
      DECLARE CUR_LOOSECASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT SKU.Sku, COUNT(DISTINCT PD.DropID)          
         FROM #PickDetail_WIP PD                  
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku        
         JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
         WHERE PD.UOM IN('6','7')         
         GROUP BY SKU.Sku
         ORDER BY SKU.Sku 
                        
      OPEN CUR_LOOSECASE  
       
      FETCH NEXT FROM CUR_LOOSECASE INTO @c_Sku, @n_TotalDropID 
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	       	      	          	    
      	 SET @n_SharePltIdCnt = 0  

      	 IF @c_ResetDropIdCnt = 'Y'
      	    SET @n_DropIdCnt = 0
      	       	 
      	 IF @n_TotalDropID > (@n_MaxFullCntPerPallet - @n_DropIdCnt) --if cannot fit all dropid of the sku open new pallet
      	    SET @n_DropIdCnt = 0 --New pallet

         IF @n_TotalDropID >= @n_PltNoMixSkuMinCartonCnt  --The sku dropid more than a pallet no mix sku mininum count
      	 BEGIN      	 	
           	SET @c_ResetDropIdCnt = 'Y'  --Next sku open new pallet
      	    SET @n_DropIdCnt = 0         --New pallet for current load
      	    --SET @n_SharePltIdCnt = 1    
         END
         ELSE
           	SET @c_ResetDropIdCnt = 'N'  --Next sku share open pallet
           	      	       	 
         DECLARE CUR_LOOSECASE_DROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT DISTINCT PD.DropID
            FROM #PickDetail_WIP PD
            JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            WHERE SKU.Sku = @c_Sku
            AND PD.UOM IN('6','7')            
            ORDER BY PD.DropID

         OPEN CUR_LOOSECASE_DROPID  
        
         FETCH NEXT FROM CUR_LOOSECASE_DROPID INTO @c_DropID
   
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
         BEGIN      	          	  
         	  IF @n_DropIdCnt = 0
         	  BEGIN
         	  	IF @n_SharePltIdCnt <= 1  -- 0=no share or 1=first pallet. 2nd share onward use share pallet id
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
                  
                  SET @n_SkuCnt = @n_MaxPltSku
              END
              
              IF @n_SharePltIdCnt > 0  
                 SET @n_SharePltIdCnt = @n_SharePltIdCnt + 1	  	                  
            END

         	  SET @n_DropID_seq_Prefix = @n_DropID_seq_Prefix + 1
         	  SET @n_DropID_seq_Wave = @n_DropID_seq_Wave + 1	  
         	  SET @n_DropIDCnt = @n_DropIdCnt + 1
         	           	  
         	  IF @n_DropIdCnt >= @n_MaxFullCntPerPallet  --max dropid per pallet reach. new pallet
         	     SET @n_DropIdcnt = 0         	  
         	     
         	  SET @c_Notes = 'B-' + CAST(@n_DropID_seq_Wave AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Wave AS NVARCHAR) + '-' + CAST(@n_DropID_seq_Prefix AS NVARCHAR) + '-' + CAST(@n_PLTID_Seq_Prefix AS NVARCHAR)  + '-' + @c_PalletId
         	     
         	  UPDATE #PickDetail_WIP 
         	  SET Notes = @c_Notes   
         	  WHERE DropId = @c_DropID         	           	  
         	  
            FETCH NEXT FROM CUR_LOOSECASE_DROPID INTO @c_DropID
         END
         CLOSE CUR_LOOSECASE_DROPID
         DEALLOCATE CUR_LOOSECASE_DROPID
         
         SET @n_SkuCnt = @n_SkuCnt - 1 
         
         IF @n_SkuCnt <= 0 OR @n_SharePltIdCnt > 0 --New pallet if max sku per pallet reach and if share pallet not mix next sku with current pallet
            SET @n_DropIdcnt = 0
                                              	 
         FETCH NEXT FROM CUR_LOOSECASE INTO @c_Sku, @n_TotalDropID
      END
      CLOSE CUR_LOOSECASE
      DEALLOCATE CUR_LOOSECASE                          
   END      
    
   --NJOW01
   --Assign pallet to loose/conso carton (uom 6 & 7)   
   IF @n_continue IN(1,2) AND @c_Wavetype = '2'
      AND ISNULL(@c_WaveType2LooseAssignPlt,'') <> 'Y'    
   BEGIN   	                 	
   	 --Loop each sku
     DECLARE CUR_LOOSECASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT SKU.Storerkey, SKU.Sku, SUM(PD.Qty), PACK.CaseCnt
         FROM #PickDetail_WIP PD                  
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku        
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         WHERE PD.UOM IN('6','7')         
      	 AND ISNULL(PD.Notes,'') = ''         
         GROUP BY SKU.Storerkey, SKU.Sku, PACK.CaseCnt
         ORDER BY SKU.Storerkey, SKU.Sku 
                        
      OPEN CUR_LOOSECASE  
       
      FETCH NEXT FROM CUR_LOOSECASE INTO @c_Storerkey, @c_Sku, @n_TotalPickQty, @n_CaseCnt 

      SET @n_SeqNo = 0      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)         
      BEGIN      	        	
      	 --Loop total sku qty split by seq#. max 4 cartons per seq#
      	 WHILE @n_TotalPickQty > 0 AND @n_CaseCnt > 0 AND @n_continue IN(1,2)
      	 BEGIN      	      	      	         	    
      	 	  SET @n_SeqNo = @n_SeqNo + 1     	 
      	    SET @n_CurrSeqQty =  @n_CaseCnt * 4
      	    
      	    IF @n_CurrSeqQty > @n_TotalPickQty 
      	       SET @n_CurrSeqQty = @n_TotalPickQty
      	    
      	    SET @n_TotalPickQty = @n_TotalPickQty - @n_CurrSeqQty
      	    
      	    --Loop pickdetail to assign seq#
      	    DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      	       SELECT PD.Pickdetailkey, PD.Qty
      	       FROM #PickDetail_WIP PD 
      	       JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      	       WHERE PD.Storerkey = @c_Storerkey
               AND PD.Sku = @c_Sku
               AND PD.UOM IN('6','7')   
      	       AND ISNULL(PD.Notes,'') = ''
      	       ORDER BY PD.Loc, PD.UOM
      	 
      	    OPEN CUR_PICK  
       
            FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PickQty
            
            WHILE @@FETCH_STATUS = 0 AND @n_CurrSeqQty > 0 AND @n_continue IN(1,2)        
            BEGIN
         	     IF @n_CurrSeqQty >= @n_pickQty
         	     BEGIN
                  UPDATE #PickDetail_WIP WITH (ROWLOCK)
                  SET Notes = CAST(@n_SeqNo AS NVARCHAR)
                  WHERE Pickdetailkey = @c_Pickdetailkey                  
                  
                  SELECT @n_CurrSeqQty = @n_CurrSeqQty - @n_pickQty
         	     END
         	     ELSE
         	     BEGIN
                  SELECT @n_SplitQty = @n_PickQty - @n_CurrSeqQty
                 
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
                              TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, WIP_Refno, Channel_ID)   --WL01               
                   SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,                                      
                          Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,       
                          DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,                                                     
                          ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,                                                      
                          WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo,                                                               
                          TaskDetailKey, TaskManagerReasonKey, Notes, MoveRefKey, @c_SourceType, Channel_ID   --WL01                                                          
                   FROM #PickDetail_WIP (NOLOCK)                                                                                             
                   WHERE PickdetailKey = @c_PickdetailKey         
                              
                   SELECT @n_err = @@ERROR
                   
                   IF @n_err <> 0     
                   BEGIN     
                      SELECT @n_continue = 3      
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050   
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   END
               
             	     UPDATE #PickDetail_WIP WITH (ROWLOCK) 
                   SET Notes = CAST(@n_SeqNo AS NVARCHAR),
                       UOMQTY = CASE UOM WHEN '6' THEN @n_CurrSeqQty ELSE UOMQty END, 
                       Qty = @n_CurrSeqQty 
                   WHERE Pickdetailkey = @c_PickdetailKey
                                                                                                           
                   SELECT @n_err = @@ERROR
                   IF @n_err <> 0 
                   BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38060   
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK12)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                   END
                   
                   SELECT @n_CurrSeqQty = 0
         	     END         	             	    
            	  
               FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey, @n_PickQty
            END
            CLOSE CUR_PICK
            DEALLOCATE CUR_PICK                  	    
      	 END   
      	 
         FETCH NEXT FROM CUR_LOOSECASE INTO @c_Storerkey, @c_Sku, @n_TotalPickQty, @n_CaseCnt 
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
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK12'		
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