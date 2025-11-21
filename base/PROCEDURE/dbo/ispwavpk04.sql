SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWAVPK04                                         */
/* Creation Date: 18-MAY-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-444 BrownShoe Pre-cartonization                         */
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
/************************************************************************/

CREATE PROC [dbo].[ispWAVPK04]   
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
   
   DECLARE @c_PairPerCtn NVARCHAR(18),   --Orderdetail.userdefine08
           @c_Solid_Musical NVARCHAR(18),  --Orderdetail.userdefine09
           @c_AllowMix NVARCHAR(18), --Orderdetail.userdefine10
           @c_Orderkey NVARCHAR(10),
           @c_PrevOrderkey NVARCHAR(10),   
           @c_LabelNo NVARCHAR(20),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20),
           @n_Qty INT,         
           @c_CartonGroup NVARCHAR(18),
           --@c_CartonType NVARCHAR(18),
           -- @n_CartonNo INT,
           @c_SourceType NVARCHAR(50),
           @c_NewCarton NCHAR(1),
           @n_PickQty INT,
           @n_PackQty INT,
           @n_splitqty INT,
           @c_PickDetailKey NVARCHAR(10),
           @c_NewPickdetailKey NVARCHAR(10),
           @n_TotalCartonNeed INT,
           @n_OrderQty INT,
           @n_CartonCount INT,
           @n_CartonQtyCanFit INT,
           @n_PickdetQty INT,
           @c_Pickslipno NVARCHAR(10),
           @c_DropID NVARCHAR(20)

   DECLARE @c_WIP_PickDetailKey nvarchar(18), 
           @c_WIP_RefNo NVARCHAR(30),
           @n_UOMQty            INT  
                           
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT
   
 	 IF @n_err =  1
	    SET @n_debug = 1
	 ELSE
	    SET @n_debug = 0		 
                                                     
	 SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1
	 
	 SET @c_WIP_RefNo = 'ispWAVPK04' 
   	 	   
   SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
   FROM WAVE (NOLOCK)
   JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey        
   WHERE WAVE.Wavekey = @c_Wavekey
      
   --Validation            
   IF @n_continue IN(1,2) 
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
                WHERE PD.Status='4' AND PD.Qty > 0 
                 AND  O.Userdefine09 = @c_WaveKey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38000     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END
      
      IF EXISTS(SELECT 1  
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
                JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
         WHERE WD.Wavekey = @c_Wavekey
                AND ISNULL(PH.Orderkey,'') = '')
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized. Not allow to run again. (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END
   END
 
   --Retrieve pickdetail and validation
   IF @n_continue IN(1,2) 
   BEGIN
      SELECT O.Orderkey,
             PD.Storerkey, 
             PD.Sku, 
             SUM(PD.Qty) AS Qty, 
             ISNULL(OD.CartonGroup,'') AS CartonGroup,
             ISNULL(OD.Userdefine08,'') AS PairPerCtn,
             ISNULL(OD.Userdefine09,'') AS Solid_Musical,
             ISNULL(OD.Userdefine10,'') AS AllowMix,
             SKU.Style,
             SKU.Susr1,
             SKU.Susr2
      INTO #TMP_PICKDETAIL             
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN CODELKUP CL (NOLOCK) ON OD.CartonGroup = CL.Code AND CL.listname = 'BWSCATYPE' AND CL.UDF01 = '1'
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY O.Orderkey,                      
               PD.Storerkey,                    
               PD.Sku,                          
               ISNULL(OD.CartonGroup,''),                  
               ISNULL(OD.Userdefine08,''),  
               ISNULL(OD.Userdefine09,''),
               ISNULL(OD.Userdefine10,''),    
               SKU.Style,                       
               SKU.Susr1,                       
               SKU.Susr2                        
                                            
      IF @n_debug = 1
         SELECT * FROM #TMP_PICKDETAIL       
         
      IF (SELECT COUNT(1) FROM #TMP_PICKDETAIL) = 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No pickdetail found for pre-cartonization (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END

      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      GROUP BY TP.Orderkey
      HAVING COUNT(DISTINCT TP.CartonGroup) > 1
                  
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' Cannot have more than 1 carton group. (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                              

      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      WHERE (ISNULL(PairPerCtn,'') IN ('0','') OR ISNUMERIC(PairPerCtn) = 0)
      AND (ISNULL(Solid_Musical,'') <> '' OR ISNULL(AllowMix,'') <> '') 
                        
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' Userdefine08(Pairs per case) value is invalid. (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                              
                            
      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      WHERE ISNULL(TP.Solid_Musical,'') NOT IN('','M','S')
             
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' Userdefine09(Musical/Solid) value is invalid. The value must be M,S or Blank (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                              

      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      WHERE ISNULL(TP.AllowMix,'') NOT IN('','MIX')
      
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38060     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' Userdefine10(Mix) value is invalid. The value must be MIX or Blank (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                            
      
      SET @c_Orderkey = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      WHERE ISNULL(TP.Solid_Musical,'') = 'M' 
      AND ISNULL(TP.AllowMix,'') = ''
      GROUP BY TP.Orderkey, TP.PairPerCtn
      HAVING (SUM(TP.Qty) / (CAST(TP.PairPerCtn AS INT) * 1.0)) % 1 <> 0
      
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38070     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' with Musical packing total quantities not tally for carton. (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                            
      
      SET @c_Orderkey = ''
      SET @c_Sku = ''
      SELECT TOP 1 @c_Orderkey = TP.Orderkey
      FROM #TMP_PICKDETAIL TP 
      JOIN (SELECT Orderkey, PairPerCtn, SUM(Qty) AS TotQty
            FROM #TMP_PICKDETAIL 
            WHERE ISNULL(Solid_Musical,'') = 'M' 
            AND ISNULL(AllowMix,'') = ''
            GROUP BY Orderkey, PairPerCtn
            ) S ON TP.Orderkey = S.Orderkey AND TP.PairPerCtn = S.PairPerCtn
      WHERE ISNULL(TP.Solid_Musical,'') = 'M' 
      AND ISNULL(TP.AllowMix,'') = ''
      GROUP BY TP.Orderkey, TP.Sku, TP.PairPerCtn, S.TotQty
      HAVING (SUM(TP.Qty) / (S.TotQty / (CAST(TP.PairPerCtn AS INT) * 1.0))) % 1 <> 0
      
      IF ISNULL(@c_Orderkey,'') <> ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38080     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Order# ' + RTRIM(@c_Orderkey) + ' SKU ' + RTRIM(@c_Sku) + ' with Musical packing quantity not tally for carton. (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END                                     
   END  
   
   IF @n_StartTCnt = 0
      BEGIN TRAN
   
   IF @n_continue IN(1,2) 
   BEGIN 
      IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
                WHERE WaveKey = @c_Wavekey)
      BEGIN
      	 DELETE PickDetail_WIP 
      	 WHERE WaveKey = @c_Wavekey
      	 AND WIP_RefNo = @c_WIP_RefNo 
      END 
      
      INSERT INTO PickDetail_WIP 
      (
      	PickDetailKey,      CaseID,      	   PickHeaderKey,
      	OrderKey,           OrderLineNumber, Lot,
      	Storerkey,          Sku,      	     AltSku,     UOM,
      	UOMQty,      	      Qty,      	     QtyMoved,   [Status],
      	DropID,      	      Loc,      	     ID,      	 PackKey,
      	UpdateSource,       CartonGroup,     CartonType,
      	ToLoc,      	      DoReplenish,     ReplenishZone,
      	DoCartonize,        PickMethod,      WaveKey,
      	EffectiveDate,      AddDate,      	 AddWho,
      	EditDate,           EditWho,      	 TrafficCop,
      	ArchiveCop,         OptimizeCop,     ShipFlag,
      	PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
      	Notes,      	      MoveRefKey,			 WIP_RefNo 
      )
      SELECT PD.PickDetailKey,  PD.CaseID,      PD.PickHeaderKey, 
      	PD.OrderKey,       PD.OrderLineNumber,  PD.Lot,
      	PD.Storerkey,      PD.Sku,      	      PD.AltSku,        PD.UOM,
      	PD.UOMQty,      	 PD.Qty,      	      PD.QtyMoved,      PD.[Status],
        DropID='',      	 PD.Loc,      	      PD.ID,      	    PD.PackKey,
      	PD.UpdateSource,   PD.CartonGroup,      PD.CartonType,
      	PD.ToLoc,      	   PD.DoReplenish,      PD.ReplenishZone,
      	PD.DoCartonize,    PD.PickMethod,       @c_Wavekey,
      	PD.EffectiveDate,  PD.AddDate,      	  PD.AddWho,
      	PD.EditDate,       PD.EditWho,      	  PD.TrafficCop,
      	PD.ArchiveCop,     PD.OptimizeCop,      PD.ShipFlag,
      	PD.PickSlipNo,     PD.TaskDetailKey,    PD.TaskManagerReasonKey,
      	PD.Notes,      	   PD.MoveRefKey,				@c_WIP_RefNo  
      FROM WAVEDETAIL WD (NOLOCK) 
      JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38090     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table (ispWAVPK04)' 
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END            
   END
   
   --Pre cartonization process
   IF @n_continue IN(1,2)   
   BEGIN
      SET @c_SourceType = ''
      SET @c_Pickslipno = ''
      SET @c_LabelNo = ''
      SET @c_NewCarton = 'Y'
      SET @c_PrevOrderkey = ''

      --Retrieve packing group
      DECLARE cur_PACKGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Orderkey,
                TP.CartonGroup,
                TP.PairPerCtn,
                TP.Solid_Musical,
                TP.AllowMix
         FROM #TMP_PICKDETAIL TP
         GROUP BY TP.Orderkey,
                  TP.CartonGroup,
                  TP.PairPerCtn,
                  TP.Solid_Musical,
                  TP.AllowMix
         ORDER BY TP.Orderkey, MIN(TP.Style), MIN(TP.Susr1), MIN(TP.Susr2)
          
      OPEN cur_PACKGROUP  
            
      FETCH NEXT FROM cur_PACKGROUP INTO @c_Orderkey, @c_CartonGroup, @c_PairPerCtn, @c_Solid_Musical, @c_AllowMix
      WHILE @@FETCH_STATUS = 0  
      BEGIN          	
      	 IF @c_PrevOrderkey <> @c_Orderkey
      	 BEGIN
      	 	  --Create pickslip
      	 	  GOTO CREATE_PICKSLIP
      	 	  RTN_CREATE_PICKSLIP:
      	 	  --Create Packheader
      	 	  GOTO CREATE_PACKHEADER
      	 	  RTN_CREATE_PACKHEADER:      	 	        	 	        	 	        	 	        	 	
      	 END
      	 
      	 SET @c_NewCarton = 'Y'
 	       SET @c_SourceType = ''
      	
         IF @c_Solid_Musical = 'S' AND @c_AllowMix <> 'MIX'  --one sku one carton with pair per carton(userdefine08). Remain qty new carton without mix with other sku.
         BEGIN
         	  SET @c_SourceType = 'PACKBYNOMIX'
         	  
            IF OBJECT_ID('tempdb..#TMP_PICKNOMIX','u') IS NOT NULL
               DROP TABLE #TMP_PICKNOMIX
         	  
            SELECT TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2, FLOOR(SUM(TP.Qty) / CAST(@c_PairPerCtn AS INT)) * CAST(@c_PairPerCtn AS INT) AS Qty, '1' AS Seq 
            INTO #TMP_PICKNOMIX
            FROM #TMP_PICKDETAIL TP
            WHERE Orderkey = @c_Orderkey
            AND CartonGroup = @c_CartonGroup
            AND PairPerCtn = @c_PairPerCtn
            AND Solid_Musical = @c_Solid_Musical
            AND AllowMix = @c_AllowMix
            GROUP BY TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2
            HAVING FLOOR(SUM(TP.Qty) / CAST(@c_PairPerCtn AS INT)) > 0
            UNION ALL
            SELECT TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2, SUM(TP.Qty) % CAST(@c_PairPerCtn AS INT) AS Qty, '2' AS Seq 
            FROM #TMP_PICKDETAIL TP
            WHERE Orderkey = @c_Orderkey
            AND CartonGroup = @c_CartonGroup
            AND PairPerCtn = @c_PairPerCtn
            AND Solid_Musical = @c_Solid_Musical
            AND AllowMix = @c_AllowMix
            GROUP BY TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2
            HAVING SUM(TP.Qty) % CAST(@c_PairPerCtn AS INT) > 0
                         	           	  
            DECLARE cur_PICKDETAIL_NOMIX CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TP.Storerkey, TP.Sku, TP.Qty
               FROM #TMP_PICKNOMIX TP
               ORDER BY TP.Seq, TP.Style, TP.Susr1, TP.Susr2, TP.Sku
 
            OPEN cur_PICKDETAIL_NOMIX  
            
            FETCH NEXT FROM cur_PICKDETAIL_NOMIX INTO @c_Storerkey, @c_Sku, @n_PickQty
            WHILE @@FETCH_STATUS = 0  
            BEGIN            	 
               WHILE @n_PickQty > 0 
               BEGIN         	  	 
                  GOTO CREATE_LABELNO  
                  RTN_CREATE_LABELNO_NOMIX:

                  SET @n_Qty = CAST(@c_PairPerCtn AS INT)
                  
                  IF @n_Qty > @n_PickQty
                     SET @n_Qty = @n_PickQty
                     
                  SET @n_PickQty = @n_PickQty - @n_Qty

      	          --Create packdetail
      	          GOTO CREATE_PACKDETAIL
      	          RTN_CREATE_PACKDETAIL_NOMIX:                  
               END
            	          	
               FETCH NEXT FROM cur_PICKDETAIL_NOMIX INTO @c_Storerkey, @c_Sku, @n_PickQty
            END
            CLOSE cur_PICKDETAIL_NOMIX  
            DEALLOCATE cur_PICKDETAIL_NOMIX    
            
            DROP TABLE #TMP_PICKNOMIX                                        	            
         END
         
         IF @c_Solid_Musical = 'S' AND @c_AllowMix = 'MIX'  --one sku one carton with pair per carton(userdefine08). Remain qty new carton mix with other sku.
         BEGIN
         	  SET @c_SourceType = 'PACKBYMIX'
           
            IF OBJECT_ID('tempdb..#TMP_PICKMIX','u') IS NOT NULL
               DROP TABLE #TMP_PICKMIX
         	  
            SELECT TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2, FLOOR(SUM(TP.Qty) / CAST(@c_PairPerCtn AS INT)) * CAST(@c_PairPerCtn AS INT) AS Qty, '1' AS Seq 
            INTO #TMP_PICKMIX
            FROM #TMP_PICKDETAIL TP
            WHERE Orderkey = @c_Orderkey
            AND CartonGroup = @c_CartonGroup
            AND PairPerCtn = @c_PairPerCtn
            AND Solid_Musical = @c_Solid_Musical
            AND AllowMix = @c_AllowMix
            GROUP BY TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2
            HAVING FLOOR(SUM(TP.Qty) / CAST(@c_PairPerCtn AS INT)) > 0
            UNION ALL
            SELECT TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2, SUM(TP.Qty) % CAST(@c_PairPerCtn AS INT) AS Qty, '2' AS Seq 
            FROM #TMP_PICKDETAIL TP
            WHERE Orderkey = @c_Orderkey
            AND CartonGroup = @c_CartonGroup
            AND PairPerCtn = @c_PairPerCtn
            AND Solid_Musical = @c_Solid_Musical
            AND AllowMix = @c_AllowMix
            GROUP BY TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2
            HAVING SUM(TP.Qty) % CAST(@c_PairPerCtn AS INT) > 0
                         	           	  
            DECLARE cur_PICKDETAIL_MIX CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TP.Storerkey, TP.Sku, TP.Qty
               FROM #TMP_PICKMIX TP
               ORDER BY TP.Seq, TP.Style, TP.Susr1, TP.Susr2, TP.Sku
 
            OPEN cur_PICKDETAIL_MIX  
                        
            FETCH NEXT FROM cur_PICKDETAIL_MIX INTO @c_Storerkey, @c_Sku, @n_PickQty
            WHILE @@FETCH_STATUS = 0  
            BEGIN            	 
               WHILE @n_PickQty > 0 
               BEGIN 
               	  IF @c_NewCarton = 'Y'
               	  BEGIN 
                     GOTO CREATE_LABELNO  
                     RTN_CREATE_LABELNO_MIX:
                     SET @n_CartonQtyCanFit = CAST(@c_PairPerCtn AS INT)
                     SET @c_NewCarton = 'N'
                  END
               	  
               	  IF @n_PickQty > @n_CartonQtyCanFit
               	     SET @n_Qty = @n_CartonQtyCanFit
               	  ELSE
               	     SET @n_Qty = @n_PickQty
               	                    	                        
                  SET @n_PickQty = @n_PickQty - @n_Qty
              	  SET @n_CartonQtyCanFit = @n_CartonQtyCanFit - @n_Qty
              	  
              	  IF @n_CartonQtyCanFit <= 0
              	     SET @c_NewCarton = 'Y'

      	          --Create packdetail
      	          GOTO CREATE_PACKDETAIL
      	          RTN_CREATE_PACKDETAIL_MIX:                  
               END
            	          	
               FETCH NEXT FROM cur_PICKDETAIL_MIX INTO @c_Storerkey, @c_Sku, @n_PickQty
            END
            CLOSE cur_PICKDETAIL_MIX  
            DEALLOCATE cur_PICKDETAIL_MIX    
            
            DROP TABLE #TMP_PICKMIX                                            	  
         END

         IF @c_Solid_Musical = 'M' AND @c_AllowMix = ''  --Sku evently pack to every carton.
         BEGIN
         	  SET @c_SourceType = 'PACKBYEVENTLY'
         	  
         	  SELECT @n_OrderQty = SUM(Qty)
         	  FROM #TMP_PICKDETAIL TP
            WHERE Orderkey = @c_Orderkey
            AND CartonGroup = @c_CartonGroup
            AND PairPerCtn = @c_PairPerCtn
            AND Solid_Musical = @c_Solid_Musical
            AND AllowMix = @c_AllowMix
                        
            SET @n_TotalCartonNeed = @n_OrderQty / CAST(@c_PairPerCtn AS INT)
            
            SET @n_CartonCount = @n_TotalCartonNeed
            WHILE @n_CartonCount > 0
            BEGIN
               GOTO CREATE_LABELNO  
               RTN_CREATE_LABELNO_EVENTLY:
            	
               DECLARE cur_PICKDETAIL_EVENTLY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT Storerkey, Sku, SUM(Qty) / @n_TotalCartonNeed
         	        FROM #TMP_PICKDETAIL TP
                  WHERE Orderkey = @c_Orderkey
                  AND CartonGroup = @c_CartonGroup
                  AND PairPerCtn = @c_PairPerCtn
                  AND Solid_Musical = @c_Solid_Musical
                  AND AllowMix = @c_AllowMix
                  GROUP BY Storerkey, Sku, Style, Susr1, Susr2
                  ORDER BY Style, Susr1, Susr2, Sku
                     	          
 	             OPEN cur_PICKDETAIL_EVENTLY  
               
               FETCH NEXT FROM cur_PICKDETAIL_EVENTLY INTO @c_Storerkey, @c_Sku, @n_Qty
               
               WHILE @@FETCH_STATUS = 0
               BEGIN
      	          --Create packdetail
      	          GOTO CREATE_PACKDETAIL
      	          RTN_CREATE_PACKDETAIL_EVENTLY:                  
               	
                  FETCH NEXT FROM cur_PICKDETAIL_EVENTLY INTO @c_Storerkey, @c_Sku, @n_Qty
               END  
               CLOSE cur_PICKDETAIL_EVENTLY
               DEALLOCATE cur_PICKDETAIL_EVENTLY
               
               SELECT @n_CartonCount = @n_CartonCount - 1 
            END
         END

         IF @c_Solid_Musical = '' AND @c_AllowMix = ''  --one piece one carton
         BEGIN
         	  SET @c_SourceType = 'PACKBYPIECE'

            DECLARE cur_PICKDETAIL_PIECE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TP.Storerkey, TP.Sku, SUM(TP.Qty)
               FROM #TMP_PICKDETAIL TP
               WHERE Orderkey = @c_Orderkey
               AND CartonGroup = @c_CartonGroup
               AND PairPerCtn = @c_PairPerCtn
               AND Solid_Musical = @c_Solid_Musical
               AND AllowMix = @c_AllowMix
               GROUP BY TP.Storerkey, TP.Sku, TP.Style, TP.Susr1, TP.Susr2
               ORDER BY TP.Style, TP.Susr1, TP.Susr2, TP.Sku
 
            OPEN cur_PICKDETAIL_PIECE  
            
            SET @n_Qty = 1
            FETCH NEXT FROM cur_PICKDETAIL_PIECE INTO @c_Storerkey, @c_Sku, @n_PickQty
            WHILE @@FETCH_STATUS = 0  
            BEGIN          	
            	 WHILE @n_PickQty > 0
            	 BEGIN            	 	  
               	  --Create label no
      	          GOTO CREATE_LABELNO
      	          RTN_CREATE_LABELNO_PIECE:
      	 
      	          --Create packdetail
      	          GOTO CREATE_PACKDETAIL
      	          RTN_CREATE_PACKDETAIL_PIECE:
            	    
            	    SET @n_PickQty = @n_PickQty - 1
            	 END
               FETCH NEXT FROM cur_PICKDETAIL_PIECE INTO @c_Storerkey, @c_Sku, @n_PickQty               
            END
            CLOSE cur_PICKDETAIL_PIECE  
            DEALLOCATE cur_PICKDETAIL_PIECE                                            	
         END
      	
         FETCH NEXT FROM cur_PACKGROUP INTO @c_Orderkey, @c_CartonGroup, @c_PairPerCtn, @c_Solid_Musical, @c_AllowMix
      END  	       	 
      CLOSE cur_PACKGROUP  
      DEALLOCATE cur_PACKGROUP                                            	
   END
      
   DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey, CaseID, Qty, UOMQty, PickSlipNo 
   FROM PickDetail_WIP WITH (NOLOCK)
   WHERE WaveKey = @c_Wavekey 
   AND WIP_RefNo = @c_WIP_RefNo
   ORDER BY PickDetailKey 
   
   OPEN cur_PickDetailKey
   
   FETCH FROM cur_PickDetailKey INTO @c_WIP_PickDetailKey, @c_labelno, @n_packqty, @n_UOMQty, @c_PickslipNo
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	
   	SET @c_DropID = RIGHT(LTRIM(RTRIM(@c_labelno)), 18)
   	
   	IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
   	          WHERE PickDetailKey = @c_WIP_PickDetailKey)
   	BEGIN
   		UPDATE PICKDETAIL WITH (ROWLOCK) 
   		   SET DropID = @c_DropID, 
   		       Qty = @n_PackQty, 
   		       UOMQty = @n_UOMQty, 
   		       PickSlipNo = @c_PickslipNo,
   		       WaveKey = @c_Wavekey,
   		       EditDate = GETDATE(),   	   		        	       
   		       TrafficCop = NULL
   		WHERE PickDetailKey = @c_WIP_PickDetailKey  
   		
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38100     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK04)' + ' ( ' 
            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP 
			END   		
   	END
   	ELSE 
      BEGIN      	
      	 INSERT INTO PICKDETAIL 
               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                Taskdetailkey, TaskManagerReasonkey, Notes )
         SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                @c_DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, 
                Taskdetailkey, TaskManagerReasonkey, Notes
         FROM PickDetail_WIP AS wpd WITH (NOLOCK)
         WHERE wpd.PickDetailKey = @c_WIP_PickDetailKey
         AND wpd.WIP_RefNo = @c_WIP_RefNo
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38110     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK04)' + ' ( ' 
               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP 
			   END         
      END
   
   	  FETCH FROM cur_PickDetailKey INTO @c_WIP_PickDetailKey, @c_labelno, @n_packqty, @n_UOMQty, @c_PickslipNo 
   END
   
   CLOSE cur_PickDetailKey
   DEALLOCATE cur_PickDetailKey
               
   QUIT_SP:

   IF (SELECT CURSOR_STATUS('LOCAL','cur_PACKGROUP')) >=0 
   BEGIN
      CLOSE cur_PACKGROUP           
      DEALLOCATE cur_PACKGROUP      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDETAIL_NOMIX')) >=0 
   BEGIN
      CLOSE cur_PICKDETAIL_NOMIX           
      DEALLOCATE cur_PICKDETAIL_NOMIX      
   END
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDETAIL_MIX')) >=0 
   BEGIN
      CLOSE cur_PICKDETAIL_MIX           
      DEALLOCATE cur_PICKDETAIL_MIX      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDETAIL_EVENTLY')) >=0 
   BEGIN
      CLOSE cur_PICKDETAIL_EVENTLY           
      DEALLOCATE cur_PICKDETAIL_EVENTLY      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDETAIL_PIECE')) >=0 
   BEGIN
      CLOSE cur_PICKDETAIL_PIECE           
      DEALLOCATE cur_PICKDETAIL_PIECE      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PickDetailKey')) >=0 
   BEGIN
      CLOSE cur_PickDetailKey           
      DEALLOCATE cur_PickDetailKey
   END                                                                                                                                                                       
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PICKDET_UPDATE')) >=0 
   BEGIN
      CLOSE CUR_PICKDET_UPDATE           
      DEALLOCATE CUR_PICKDET_UPDATE
   END  
   
   IF OBJECT_ID('tempdb..#TMP_PICKDETAIL','u') IS NOT NULL
      DROP TABLE #TMP_PICKDETAIL;
   IF OBJECT_ID('tempdb..#TMP_PICKNOMIX','u') IS NOT NULL
      DROP TABLE #TMP_PICKNOMIX;
   IF OBJECT_ID('tempdb..#TMP_PICKMIX','u') IS NOT NULL
      DROP TABLE #TMP_PICKMIX;

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
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK04'		
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
	 
	 -----------------Create Label No--------------
	 CREATE_LABELNO:
	 
	 EXEC isp_GLBL08 
         @c_PickSlipNo  
        ,1
        ,@c_LabelNo OUTPUT
	
   IF @c_SourceType = 'PACKBYPIECE'
      GOTO RTN_CREATE_LABELNO_PIECE                  
   IF @c_SourceType = 'PACKBYNOMIX'
      GOTO RTN_CREATE_LABELNO_NOMIX
   IF @c_SourceType = 'PACKBYEVENTLY'      
      GOTO RTN_CREATE_LABELNO_EVENTLY           
   IF @c_SourceType = 'PACKBYMIX'      
      GOTO RTN_CREATE_LABELNO_MIX           
    
	 -----------------Create Pickslip--------------	 
	 CREATE_PICKSLIP:
	 
   SET @c_PickSlipno = ''      
   SELECT @c_PickSlipno = PickheaderKey  
   FROM PickHeader (NOLOCK)  
   WHERE Orderkey = @c_Orderkey
                 
   -- Create Pickheader      
   IF ISNULL(@c_PickSlipno ,'') = ''  
   BEGIN  
      EXECUTE dbo.nspg_GetKey   
      'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38240     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PICKSLIP) (ispWAVPK04)'
          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
        
      SELECT @c_Pickslipno = 'P'+@c_Pickslipno      
                 
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderkey, PickType, Zone, TrafficCop)  
                      VALUES (@c_Pickslipno , @c_OrderKey, '', '0', '3', '')              

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38250     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Pickheader Table (ispWAVPK04)' 
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
      
      DECLARE cur_Update_PickDetail_Wip2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetail_WIP.PickDetailKey
      FROM PICKDETAIL (NOLOCK)
      JOIN PickDetail_WIP WITH (NOLOCK) ON PICKDETAIL.Orderkey = PickDetail_WIP.Orderkey
      WHERE PICKDETAIL.OrderKey = @c_OrderKey 
      AND PickDetail_WIP.WIP_RefNo = @c_WIP_Refno
      
      OPEN cur_Update_PickDetail_Wip2
      
      FETCH FROM cur_Update_PickDetail_Wip2 INTO @c_WIP_PickDetailKey
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail_WIP WITH (ROWLOCK)  
         SET    PickSlipNo = @c_PickSlipNo
               ,EditDate = GETDATE()   
               ,TrafficCop = NULL  
         WHERE PickDetailKey = @c_WIP_PickDetailKey      
         AND WIP_RefNo = @c_WIP_Refno

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38260     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail_Wip Table (ispWAVPK04)' 
            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
      
      	FETCH FROM cur_Update_PickDetail_Wip2 INTO @c_WIP_PickDetailKey
      END
      
      CLOSE cur_Update_PickDetail_Wip2
      DEALLOCATE cur_Update_PickDetail_Wip2
      
      /*
      IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
         SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
         FROM PICKDETAIL (NOLOCK)  
         WHERE PickSlipNo = @c_PickSlipNo  
         
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38270     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert RefkeyLookUp Table (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END   
      END
      */
   END 
      
   -- Create PickingInfo with scanned in
   /*
   IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno) = 0
   BEGIN
      INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                       VALUES (@c_Pickslipno ,GETDATE(),sUser_sName(), NULL)
   END
   */
   
   GOTO RTN_CREATE_PICKSLIP     
       
	 -----------------Create Packheader--------------
	 CREATE_PACKHEADER:
	 
	 IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
	 BEGIN
      INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)      
             SELECT TOP 1 O.Route, O.Orderkey, '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo       
             FROM  PICKHEADER PH (NOLOCK)      
             JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)      
             WHERE PH.PickHeaderKey = @c_PickSlipNo
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38120     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispWAVPK04)'
          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
	 END

   GOTO RTN_CREATE_PACKHEADER

	 -----------------Create Packdetail--------------
	 CREATE_PACKDETAIL:
   
   -- CartonNo and LabelLineNo will be inserted by trigger    
   INSERT INTO PACKDETAIL     
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)    
   VALUES     
      (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,   
       @n_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')
       
   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38130     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packdetail Table (ispWAVPK04)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
   
   GOTO UPDATE_PICKDETAIL_LABELNO
   RTN_UPDATE_PICKDETAIL_LABELNO:
   
   /*
   SET @n_CartonNo = 0
   SELECT TOP 1 @n_CartonNo = CartonNo
   FROM PACKDETAIL (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno
   AND LabelNo = @c_LabelNo
   
   --Carete packinfo
   IF @n_CartonNo > 0 AND ISNULL(@c_CartonType,'') <> ''
   BEGIN   	     	          
   	  IF @c_SourceType = 'FULLCASE'
   	     SET @n_CartonCube = @n_Qty * @n_StdCube

      SET @n_CartonWeight = @n_Qty * @n_StdGrossWgt
   	  
   	  IF NOT EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_PickslipNo 
   	                 AND CartonNo = @n_CartonNo)
   	  BEGIN
   	  	 INSERT INTO PACKINFO (Pickslipno, CartonNo, CartonType, Cube, Weight, Qty)
   	  	 VALUES (@c_PickslipNo, @n_CartonNo, @c_CartonType, @n_CartonCube, @n_CartonWeight, @n_Qty)            
   	  	 
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38140     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packinfo Table (ispWAVPK04)'
             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END   	  	 
   	  END
   	  ELSE
   	  BEGIN
   	  	 IF @c_SourceType <> 'FULLCASE' 
   	  	 BEGIN
   	        UPDATE PACKINFO WITH (ROWLOCK)
   	        SET Weight = Weight + @n_CartonWeight,
   	            Qty = Qty + @n_Qty	   	  
   	        WHERE Pickslipno = @c_PickslipNo 
   	        AND CartonNo = @n_CartonNo
            
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38150     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Packinfo Table (ispWAVPK04)' 
               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP
            END   	 
         END 	    	     
   	  END
   END
   */

   IF @c_SourceType = 'PACKBYPIECE'
      GOTO RTN_CREATE_PACKDETAIL_PIECE        
   IF @c_SourceType = 'PACKBYNOMIX'
      GOTO RTN_CREATE_PACKDETAIL_NOMIX        
   IF @c_SourceType = 'PACKBYEVENTLY'      
      GOTO RTN_CREATE_PACKDETAIL_EVENTLY
   IF @c_SourceType = 'PACKBYMIX'      
      GOTO RTN_CREATE_PACKDETAIL_MIX
      	    
   ------------Update labelno to pickdetail caseid for BOM(Assortment)-----------      
   UPDATE_PICKDETAIL_LABELNO:
         	             
   SET @n_packqty = @n_Qty
   DECLARE CUR_PICKDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.PickDetailKey, 
             PD.Qty
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      WHERE WD.Wavekey = @c_Wavekey
      AND PD.WIP_RefNo = @c_WIP_RefNo
      AND OD.CartonGroup = @c_CartonGroup
      AND OD.Userdefine08 = @c_PairPerCtn
      AND OD.Userdefine09 = @c_Solid_Musical
      AND OD.Userdefine10 = @c_AllowMix
      AND O.Orderkey = @c_Orderkey
      AND OD.Storerkey = @c_Storerkey
      AND OD.Sku = @c_Sku
      AND ISNULL(PD.DropId,'') = ''
      ORDER BY PD.PickDetailKey
   
   OPEN CUR_PICKDET_UPDATE  
   
   FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
   
   WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0 
   BEGIN                	                                	             
      IF @n_PickdetQty <= @n_packqty
      BEGIN
      	 UPDATE PickDetail_WIP WITH (ROWLOCK)
      	 SET CaseId = @c_labelno,
      	     TrafficCop = NULL
      	 WHERE PickDetailKey = @c_PickDetailKey
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
      		 SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38160     
      		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK04)' 
      		 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
           GOTO QUIT_SP 
		   	 END
		   	 SELECT @n_packqty = @n_packqty - @n_PickdetQty
      END
      ELSE
      BEGIN  -- pickqty > packqty
      	 SELECT @n_splitqty = @n_PickdetQty - @n_packqty
	       EXECUTE nspg_GetKey
         'PICKDETAILKEY',
         10,
         @c_newpickdetailkey OUTPUT,
         @b_success OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
         	  SELECT @n_continue = 3
         	  GOTO QUIT_SP
         END
      
      	 INSERT PickDetail_WIP
                (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                 Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                 DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                 WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes)
         SELECT @c_newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes
         FROM PickDetail_WIP (NOLOCK)
         WHERE PickDetailKey = @c_PickDetailKey
      
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38170     
      	    SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK04)' + ' ( ' 
      	           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      
         UPDATE PickDetail_WIP WITH (ROWLOCK)
      	 SET CaseId = @c_labelno,
      	     Qty = @n_packqty,
		   	     UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END,
		   	     EditDate = GETDATE(), 
      	     TrafficCop = NULL
      	 WHERE PickDetailKey = @c_PickDetailKey
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
      		  SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38180     
      		  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (isp_AssignPackLabelToOrderByLoad)' 
      		         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
        	  GOTO QUIT_SP
		    END
      
         SELECT @n_packqty = 0
      END
      FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
   END
   CLOSE CUR_PICKDET_UPDATE  
   DEALLOCATE CUR_PICKDET_UPDATE                

   GOTO RTN_UPDATE_PICKDETAIL_LABELNO
 END  

GO