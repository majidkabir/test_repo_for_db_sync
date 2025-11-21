SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store Procedure:  isp_batching_task_summary_07                       */  
/* Creation Date:  20-Jun-2023                                          */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-22685[CN] Lululemon SCE View Report Add Ecom Task Summry*/  
/*          &Pickslip Reports CR                                        */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author  Ver.  Purposes                                   */  
/* 20-06-2023  CSCHONG 1.0   DevOps Combine Script                      */   
/************************************************************************/  
  
CREATE    PROC [dbo].[isp_batching_task_summary_07] (  
            @c_Loadkey_from NVARCHAR(10)  
           ,@c_Loadkey_to NVARCHAR(10) = ''  
           ,@c_OrderCount NVARCHAR(10) = '9999'  
           ,@c_Pickzone NVARCHAR(1000) = ''  
           ,@c_Mode NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single  
           ,@c_ReGen NVARCHAR(10) = 'N' --Regnerate flag Y/N     
           ,@c_updatepick  NCHAR(5) = 'N'   
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
           ,@c_Getloadkey                NVARCHAR(10)   
           ,@n_ctnstorerkey              INT   = 0  
           ,@n_Maxorders                 INT = 10000  
           ,@n_ctnord                    INT = 0    
           ,@c_FromStorerkey             NVARCHAR(10)
           ,@c_ToStorerkey               NVARCHAR(10)
           ,@c_GetStorerkey              NVARCHAR(10)   
                       
  
    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)  
    SELECT @c_ZoneList = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT   
              
    IF ISNULL(@c_PickZone,'') = ''  
       SET @c_PickZone = ''  
         
         
    IF @c_Mode NOT IN('1','4','5','9')  
    BEGIN   
       SELECT @n_Continue = 3    
       SELECT @n_Err = 63200    
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_summary_07)'   
       GOTO Quit  
    END  

    SELECT TOP 1 @c_FromStorerkey = OH.storerkey
    FROM ORDERS OH WITH (NOLOCK)
    WHERE OH.LoadKey = @c_Loadkey_from

    SELECT TOP 1 @c_ToStorerkey = OH.storerkey
    FROM ORDERS OH WITH (NOLOCK)
    WHERE OH.LoadKey = @c_Loadkey_to

   IF @c_FromStorerkey <> @c_ToStorerkey
   BEGIN  
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63220  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': From storerkey and To storerkey is not same (isp_batching_task_pickslip_08)'  
       GOTO Quit  
   END
   ELSE
   BEGIN
       SET @c_GetStorerkey = @c_FromStorerkey
   END 
  
  
      CREATE TABLE #TMPLOADLIST  
      (  loadkey       NVARCHAR(10),  
         storerkey     NVARCHAR(10),  
         OrdCnt        INT,  
       Errmsg        NVARCHAR(250) NULL  
      )  
  
   INSERT INTO #TMPLOADLIST  
   (  
       loadkey,  
       storerkey,  
       OrdCnt,  
       Errmsg  
   )  
   SELECT DISTINCT O.loadkey,O.StorerKey,COUNT(DISTINCT O.OrderKey),''  
   FROM dbo.ORDERS O WITH (NOLOCK)  
   WHERE O.LoadKey >= @c_Loadkey_from AND O.LoadKey <= @c_Loadkey_to   
   AND O.StorerKey = @c_GetStorerkey 
   GROUP BY O.loadkey,O.StorerKey  
  
  
   SELECT @n_ctnstorerkey = COUNT(DISTINCT storerkey)  
         ,@n_ctnord = SUM(OrdCnt)  
   FROM #TMPLOADLIST  
   WHERE LoadKey >= @c_Loadkey_from AND LoadKey <= @c_Loadkey_to   
   AND StorerKey = @c_GetStorerkey 
  
   
  
   IF @n_ctnord > @n_Maxorders  
   BEGIN  
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63230  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': No of orders retrieve more than maximun orders allow (isp_batching_task_pickslip_08)'  
       GOTO Quit  
   END  
  
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT loadkey     
   FROM   #TMPLOADLIST   
   where StorerKey = @c_GetStorerkey 
    
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_GetLoadkey      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
  
    SELECT TOP 1 @c_Storerkey = Storerkey  
                ,@c_Facility = Facility  
    FROM ORDERS (NOLOCK)  
    WHERE Loadkey = @c_Getloadkey        
      
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
                        FROM LOADPLANDETAIL LPD (NOLOCK)  
                        JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey  
                        JOIN ORDERINFO OI (NOLOCK) ON O.Orderkey = OI.Orderkey  
                        WHERE LPD.Loadkey = @c_GetLoadkey   
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
         FROM ORDERS O (NOLOCK)  
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
         JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
         WHERE LPD.Loadkey = @c_GetLoadkey  
         GROUP BY LOC.Descr      
         ORDER BY LOC.Descr FOR XML PATH('')),1,1,'' ) + ','   
      END  
      ELSE  
      BEGIN       
         SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)             
         FROM ORDERS O (NOLOCK)  
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
         JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
         WHERE LPD.Loadkey = @c_GetLoadkey  
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
                '',                     
                'PickByVoicePicking', -- Configkey  
                @b_success            OUTPUT,  
                @c_PickByVP           OUTPUT,  
                @n_err                OUTPUT,  
                @c_errmsg             OUTPUT               
            
        IF ISNULL(@c_PickByVP,'') = '1'  
        BEGIN  
            SELECT @c_LPUDF10 = LP.Userdefine10  
            FROM LOADPLAN LP WITH (NOLOCK)  
            WHERE LP.Loadkey = @c_GetLoadkey  
  
            IF ISNULL(@c_LPUDF10,'') = ''  
            BEGIN  
  
                UPDATE Loadplan WITH (ROWLOCK)  
                SET Userdefine10 = UPPER(@c_updatepick)   
                  , EditWho    = SUSER_SNAME()  
                  , EditDate   = GETDATE()  
                    WHERE Loadplan.loadkey = @c_GetLoadkey  
                      
                SELECT @n_err = @@ERROR  
                  
                IF @n_err <> 0   
                BEGIN  
                  SELECT @n_Continue = 3    
                  SELECT @n_Err = 63210    
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_batching_task_summary_07)'   
                  GOTO Quit  
                END  
            END   
        END       
   END  
  
    IF @c_ReGen = 'Y'  
       SET @c_CallSource = 'RPTREGEN'  
    ELSE  
       SET @c_CallSource = 'RPT'     
  
    WHILE @@TRANCOUNT > 0  
      COMMIT  
        
    BEGIN TRAN    
  
  
    EXEC ispOrderBatching  
         @c_LoadKey     = @c_GetLoadkey  
        ,@n_OrderCount  = @n_OrderCount    
        ,@c_PickZones   = @c_PickZone  
        ,@c_Mode        = @c_Mode  
        ,@b_Success     = @b_Success   OUTPUT    
        ,@n_Err         = @n_Err       OUTPUT    
        ,@c_ErrMsg      = @c_ErrMsg    OUTPUT  
        ,@c_CallSource  = @c_CallSource  
        ,@c_updatepick  = @c_updatepick  
  
  
    IF @b_Success = 0  
    BEGIN         
       ROLLBACK  
       SELECT @n_Continue = 3  
       GOTO Quit  
    END      
  
    WHILE @@TRANCOUNT > 0  
      COMMIT  
  
      FETCH NEXT FROM CUR_RESULT INTO @c_GetLoadkey      
      END  
  
      CLOSE CUR_RESULT  
      DEALLOCATE CUR_RESULT  
   
  
  
    IF @c_OrderBatchBylocdescr = '1'    
    BEGIN  
  
       SELECT PT.TaskBatchNo,   
              PD.Notes,   
              LP.Loadkey,   
              COUNT(DISTINCT PD.Sku) AS NoOfSku,  
              SUM(PD.Qty) AS Qty,  
              L.Descr,  
              CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                   CL.Long  
              ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,  
              COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,  
              ISNULL(CL1.Short,'N') AS ShowSalesman,    
              CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Salesman,    
              ISNULL(CL2.Short,'N') AS ShowSalesman,   
              CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Shipperkey,     
              ISNULL(CL3.Short,'N') AS ShowLoadkeyBarcode,    
              CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN N'Task Summary Report - ' + TRIM(PD.Storerkey) ELSE N'' END AS ShowTitleWithStorer    
       FROM #TMPLOADLIST LP (NOLOCK)  
       JOIN Orders OH WITH (NOLOCK) ON OH.LoadKey = LP.loadkey  
       JOIN PICKDETAIL PD (NOLOCK) ON OH.orderkey = PD.OrderKey  
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
       LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE'   
       LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman'   
                                       AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL1.Short,'') <> 'N')    
       LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier'   
                                       AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL2.Short,'') <> 'N')    
       LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowLoadkeyBarcode'   
                                       AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL3.Short,'') <> 'N')    
       LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowTitleWithStorer'   
                                       AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL4.Short,'') <> 'N')    
       WHERE LP.Loadkey >= @c_Loadkey_from AND LP.LoadKey <= @c_Loadkey_to   
       AND L.Descr IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone))   
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode  
       GROUP BY PT.TaskBatchNo,   
                PD.Notes,   
                LP.Loadkey,  
                L.Descr,  
                CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                   CL.Long  
                ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,  
                ISNULL(CL1.Short,'N'),  --WL01  
                ISNULL(CL2.Short,'N'),  --WL02  
                ISNULL(CL3.Short,'N'),  --WL02  
                CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN N'Task Summary Report - ' + TRIM(PD.Storerkey) ELSE N'' END   --WL03  
       ORDER BY LP.loadkey,L.Descr, PD.NOTES      
    END                 
    ELSE  
    BEGIN  
  
       SELECT PT.TaskBatchNo,   
              PD.Notes,   
              LP.Loadkey,   
              COUNT(DISTINCT PD.Sku) AS NoOfSku,  
              SUM(PD.Qty) AS Qty,  
              L.PickZone,  
              CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                   CL.Long  
              ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,  
              COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,  
              ISNULL(CL1.Short,'N') AS ShowSalesman,     
              CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Salesman,     
              ISNULL(CL2.Short,'N') AS ShowSalesman,     
              CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Shipperkey,     
              ISNULL(CL3.Short,'N') AS ShowLoadkeyBarcode,    
              CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN N'Task Summary Report - ' + TRIM(PD.Storerkey) ELSE N'' END AS ShowTitleWithStorer     
       FROM #TMPLOADLIST LP (NOLOCK)  
       JOIN Orders OH WITH (NOLOCK) ON OH.LoadKey = LP.loadkey  
       JOIN PICKDETAIL PD (NOLOCK) ON OH.orderkey = PD.OrderKey  
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc  
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey  
       LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE'   
       LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman'   
                                       AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL1.Short,'') <> 'N')   
       LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier'   
                                       AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL2.Short,'') <> 'N')    
       LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowLoadkeyBarcode'   
                                       AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL3.Short,'') <> 'N')   
       LEFT JOIN Codelkup CL4 (NOLOCK) ON (PD.Storerkey = CL4.Storerkey AND CL4.Code = 'ShowTitleWithStorer'   
                                       AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_batching_task_summary_07' AND ISNULL(CL4.Short,'') <> 'N')    
       WHERE LP.Loadkey >= @c_Loadkey_from AND LP.LoadKey <= @c_Loadkey_to   
       AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone))   
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode  
       GROUP BY PT.TaskBatchNo,   
                PD.Notes,   
                LP.Loadkey,  
                L.PickZone,  
                CASE WHEN ISNULL(CL.Long,'') <> '' THEN  
                   CL.Long  
                ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,  
                ISNULL(CL1.Short,'N'),    
                ISNULL(CL2.Short,'N'),    
                ISNULL(CL3.Short,'N'),   
                CASE WHEN ISNULL(CL4.Short,'N') = 'Y' THEN N'Task Summary Report - ' + TRIM(PD.Storerkey) ELSE N'' END   
       ORDER BY LP.loadkey,L.PickZone, PD.NOTES      
    END  
  
Quit:  
     
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispOrderBatching'    
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