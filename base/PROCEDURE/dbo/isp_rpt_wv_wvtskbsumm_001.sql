SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_RPT_WV_WVTSKBSUMM_001                          */
/* Creation Date: 12-Sep-2022                                           */
/* Copyright: LF                                                        */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-20707 - CN LOreal Batching Task Pickslip Summary Report */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage: RPT_WV_WVTSKBSUMM_001                                         */
/*        Copy from isp_batching_task_summary and convert for Logi Rpt  */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 12-Sep-2022 WLChooi  1.0   DevOps Combine Scipt                      */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_WVTSKBSUMM_001] (
            @c_Wavekey        NVARCHAR(10)
           ,@c_OrderCount     NVARCHAR(10) = '9999'
           ,@c_Pickzone       NVARCHAR(1000) = ''
           ,@c_Mode           NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single
           ,@c_ReGen          NVARCHAR(10) = 'N' --Regnerate flag Y/N   
           ,@c_updatepick     NCHAR(5) = 'N'
           ,@c_UOM            NVARCHAR(500) = ''    
           ,@c_rptprocess     NVARCHAR(4000) = ''  
           ,@c_PreGenRptData  NVARCHAR(10) = 'N'
 )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_OrderCount INT
           ,@b_Success    INT           
           ,@n_Err        INT           
           ,@c_ErrMsg     NVARCHAR(250)
           ,@c_ZoneList   NVARCHAR(1000) 
           ,@n_Continue   INT
           ,@n_StartTCnt  INT
           ,@c_CallSource NVARCHAR(10)        
          
    DECLARE @c_OrderBatchBylocdescr      NVARCHAR(10)
           ,@c_OrderBatchByLocDescr_OPT1 NVARCHAR(50) 
           ,@c_Storerkey                 NVARCHAR(15) 
           ,@c_Facility                  NVARCHAR(5) 
           ,@c_PickByVP                  NVARCHAR(30)
           ,@c_LPUDF10                   NVARCHAR(20)
           ,@c_Loadkey                   NVARCHAR(10)

    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)
    SELECT @c_ZoneList = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT 
            
    IF ISNULL(@c_PickZone,'') = ''
       SET @c_PickZone = ''

   IF @c_PreGenRptData = 'Y' SET @c_PreGenRptData = 'Y' ELSE SET @c_PreGenRptData = 'N'
       
    IF @c_Mode NOT IN('1','4','5','9')
    BEGIN 
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63200  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_RPT_WV_WVTSKBSUMM_001)' 
       GOTO Quit
    END

    SELECT TOP 1 @c_Storerkey = Storerkey,
                @c_Facility = Facility
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey
   WHERE WAVEDETAIL.WaveKey = @c_Wavekey       
    
    SET @c_OrderBatchBylocdescr = ''
    
    EXEC nspGetRight  
        @c_Facility  = @c_Facility   
      , @c_StorerKey = @c_StorerKey  
      , @c_sku       = NULL 
      , @c_ConfigKey = 'OrderBatchByLocDescr' 
      , @b_Success   = @b_Success         OUTPUT  
      , @c_authority = @c_OrderBatchBylocdescr   OUTPUT    
      , @n_err       = @n_err             OUTPUT    
      , @c_errmsg    = @c_errmsg          OUTPUT  
      , @c_Option1   = @c_OrderBatchByLocDescr_OPT1  OUTPUT
      
    IF @c_OrderBatchBylocdescr = '1'
    BEGIN
    	  IF @c_OrderBatchByLocDescr_OPT1 = 'TMALL' 
    	  BEGIN
    	     IF NOT EXISTS(SELECT 1 
    	                   FROM WAVEDETAIL WD (NOLOCK)
    	                   JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
    	                   JOIN ORDERINFO OI (NOLOCK) ON O.Orderkey = OI.Orderkey
    	                   WHERE WD.WaveKey = @c_Wavekey 
    	                   AND OI.StoreName = '618'
    	                   AND O.Shipperkey = 'SN')   	                   
    	     BEGIN
    	        SET @c_OrderBatchBylocdescr = '0'
    	     END             
    	  END
    END

    IF @c_PickZone = 'ALL'
    BEGIN
      IF @c_OrderBatchBylocdescr = '1'  
      BEGIN      
         SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.Descr)        
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = WD.Orderkey     
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE WD.WaveKey = @c_Wavekey
         GROUP BY LOC.Descr     
         ORDER BY LOC.Descr FOR XML PATH('')),1,1,'' ) + ','
      END
      ELSE
      BEGIN
         SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)             
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = WD.Orderkey     
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey     
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         WHERE WD.WaveKey = @c_Wavekey
         GROUP BY LOC.PickZone            
         ORDER BY LOC.PickZone FOR XML PATH('')),1,1,'' ) + ','	
      END
      
      IF ISNULL(@c_ZoneList,'') <> ''
      BEGIN
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)
          SET @c_PickZone = @c_ZoneList
      END
    END       

   IF UPPER(@c_updatepick) = 'VP'
   BEGIN
      SET @c_PickByVP = ''
      SET @c_LPUDF10 = ''
      
      Execute nspGetRight 
         @c_facility,  
         @c_StorerKey,              
         '', --@c_Sku                    
         'PickByVoicePicking', -- Configkey
         @b_success            OUTPUT,
         @c_PickByVP           OUTPUT,
         @n_err                OUTPUT,
         @c_errmsg             OUTPUT             
       
      IF ISNULL(@c_PickByVP,'') = '1' AND @c_PreGenRptData = 'Y'
      BEGIN
         DECLARE CUR_VP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LPD.Loadkey
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
         WHERE WD.WaveKey = @c_Wavekey

         OPEN CUR_VP

         FETCH NEXT FROM CUR_VP INTO @c_Loadkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_LPUDF10 = ''

            SELECT @c_LPUDF10 = LP.Userdefine10
            FROM LOADPLAN LP WITH (NOLOCK)
            WHERE LP.Loadkey = @c_loadkey
            
            IF ISNULL(@c_LPUDF10,'') = ''
            BEGIN
                UPDATE Loadplan WITH (ROWLOCK)
                SET Userdefine10 = UPPER(@c_updatepick) 
                  , EditWho    = SUSER_SNAME()
                  , EditDate   = GETDATE()
               WHERE Loadplan.loadkey = @c_loadkey
                    
                SELECT @n_err = @@ERROR
                
                IF @n_err <> 0 
                BEGIN
                  SELECT @n_Continue = 3  
                  SELECT @n_Err = 63210  
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_RPT_WV_WVTSKBSUMM_001)' 
                  GOTO Quit
               END
            END 
            FETCH NEXT FROM CUR_VP INTO @c_Loadkey
         END
         CLOSE CUR_VP
         DEALLOCATE CUR_VP
      END     
   END

   IF @c_ReGen = 'Y'
      SET @c_CallSource = 'RPTREGEN'
   ELSE
      SET @c_CallSource = 'RPT'   

   WHILE @@TRANCOUNT > 0
      COMMIT
      
   IF @c_PreGenRptData = 'Y'
   BEGIN
      BEGIN TRAN  

      EXEC dbo.ispOrderBatching @c_LoadKey      = N''                  
                              , @n_OrderCount   = @n_OrderCount                
                              , @c_PickZones    = @c_PickZone
                              , @c_Mode         = @c_Mode                     
                              , @b_Success      = @b_Success   OUTPUT    
                              , @n_Err          = @n_Err       OUTPUT            
                              , @c_ErrMsg       = @c_ErrMsg    OUTPUT      
                              , @c_CallSource   = @c_CallSource            
                              , @c_WaveKey      = @c_Wavekey                  
                              , @c_UOM          = @c_UOM                     
                              , @c_updatepick   = @c_updatepick            
                              , @c_rptprocess   = @c_rptprocess    
      
      IF @b_Success = 0
      BEGIN       
         ROLLBACK
         SELECT @n_Continue = 3
         GOTO Quit
      END    
   END
      
   WHILE @@TRANCOUNT > 0
     COMMIT

   IF @c_PreGenRptData = 'N' 
   BEGIN
      IF @c_OrderBatchBylocdescr = '1'
      BEGIN
         SELECT PT.TaskBatchNo, 
                PD.Notes, 
                WD.WaveKey, 
                COUNT(DISTINCT PD.Sku) AS NoOfSku,
                SUM(PD.Qty) AS Qty,
                L.Descr,
                CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                     CL.Long
                ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,
                COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,
                ISNULL(CL1.Short,'N') AS ShowSalesman, 
                CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE TRIM((SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.UserDefine09 = WD.WaveKey)) END AS Salesman,
                ISNULL(CL2.Short,'N') AS ShowCourier, 
                CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE TRIM((SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.UserDefine09 = WD.WaveKey)) END AS Shipperkey, 
                ISNULL(CL3.Short,'N') AS ShowWavekeyBarcode 
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.OrderKey
         JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
         JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
         LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
         LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman' 
                                         AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL1.Short,'') <> 'N')
         LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier' 
                                         AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL2.Short,'') <> 'N')
         LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowWavekeyBarcode' 
                                         AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL3.Short,'') <> 'N')
         WHERE WD.WaveKey = @c_Wavekey
         AND L.Descr IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
         AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
         GROUP BY PT.TaskBatchNo, 
                  PD.Notes, 
                  WD.WaveKey,
                  L.Descr,
                  CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                     CL.Long
                  ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,
                  ISNULL(CL1.Short,'N'),
                  ISNULL(CL2.Short,'N'),
                  ISNULL(CL3.Short,'N') 
         ORDER BY L.Descr, PD.NOTES    
      END               
      ELSE
      BEGIN
         SELECT PT.TaskBatchNo, 
                PD.Notes, 
                WD.WaveKey, 
                COUNT(DISTINCT PD.Sku) AS NoOfSku,
                SUM(PD.Qty) AS Qty,
                L.PickZone,
                CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                     CL.Long
                ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,
                COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,
                ISNULL(CL1.Short,'N') AS ShowSalesman,
                CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE TRIM((SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.UserDefine09 = WD.WaveKey)) END AS Salesman, 
                ISNULL(CL2.Short,'N') AS ShowCourier, 
                CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE TRIM((SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.UserDefine09 = WD.WaveKey)) END AS Shipperkey, 
                ISNULL(CL3.Short,'N') AS ShowWavekeyBarcode 
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.OrderKey
         JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
         JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
         LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
         LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman' 
                                         AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL1.Short,'') <> 'N')
         LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier' 
                                         AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL2.Short,'') <> 'N')
         LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowWavekeyBarcode' 
                                         AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'RPT_WV_WVTSKBSUMM_001' AND ISNULL(CL3.Short,'') <> 'N')
         WHERE WD.WaveKey = @c_Wavekey
         AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
         AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
         GROUP BY PT.TaskBatchNo, 
                  PD.Notes, 
                  WD.WaveKey,
                  L.PickZone,
                  CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                     CL.Long
                  ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,
                  ISNULL(CL1.Short,'N'),
                  ISNULL(CL2.Short,'N'),
                  ISNULL(CL3.Short,'N') 
         ORDER BY L.PickZone, PD.NOTES    
      END
   END
        
Quit:
   IF CURSOR_STATUS('LOCAL', 'CUR_VP') IN (0,1)
   BEGIN
      CLOSE CUR_VP
      DEALLOCATE CUR_VP
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
       BEGIN TRAN

   IF @n_Continue=3  -- Error Occured - Process And Return  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_RPT_WV_WVTSKBSUMM_001'  
        --RAISERROR @n_Err @c_ErrMsg  
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END /* main procedure */
GO