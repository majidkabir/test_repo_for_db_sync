SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_batching_task_summary_06                       */
/* Creation Date:  21-Jul-2021                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17520-CN - MAST_ECOM Task Summary Report CR             */
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
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/* 09-05-2022  KuanYee  1.0   INC1802488-BugFixed                       */
/*                            Add Stuff() show all PickZone(KY01)       */ 
/* 17-03-2023  CHONGCS  1.1   Devops Scripts Combine & WMS-21867(CS01)  */
/************************************************************************/

CREATE   PROC [dbo].[isp_batching_task_summary_06] (
            @c_Loadkey     NVARCHAR(10)
           ,@c_OrderCount  NVARCHAR(10) = '9999'
           ,@c_Pickzone    NVARCHAR(1000) = ''
           ,@c_Mode        NVARCHAR(10) = ''  -- 1=Multi-S 4=Multi-M 5=BIG 9=Single
           ,@c_ReGen       NVARCHAR(10) = 'N' --Regnerate flag Y/N   
           ,@c_updatepick  NCHAR(5) = 'N' 
           ,@c_ZoneType    NVARCHAR(10) = ''
           ,@c_taskbatchno NVARCHAR(20) = ''
           ,@c_RptType     NVARCHAR(5) = 'H'

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
                     

    SELECT @n_OrderCount = CONVERT(INT, @c_OrderCount)
    SELECT @c_ZoneList = '', @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT 
            
    IF ISNULL(@c_PickZone,'') = ''
       SET @c_PickZone = ''


CREATE TABLE #TMPBTBYPZ (
                           taskbatchno     NVARCHAR(20) NULL  DEFAULT(''),
                           Orderkey        NVARCHAR(20) NULL  DEFAULT(''),
                           pickzone        NVARCHAR(20) NULL  DEFAULT(''),
                           Zonetype        NVARCHAR(20) NULL  DEFAULT('')
)

CREATE TABLE #TMPBTOHSalesman (
                           taskbatchno     NVARCHAR(20) NULL  DEFAULT(''),
                           Zonetype        NVARCHAR(20) NULL  DEFAULT(''),
                           OHSalesman      NVARCHAR(80) NULL  DEFAULT('')
)

--CREATE TABLE #TMPBatchTASKSUM06 (
--                                    taskbatchn    NVARCHAR(20) NULL  DEFAULT(''),
--                                    notes         NVARCHAR(4000) NULL  DEFAULT(''),
--                                    loadkey       NVARCHAR(20) NULL  DEFAULT(''),
--                                    noofsku       INT  NULL DEFAULT(0),
--                                    qty           INT  NULL DEFAULT(0),
--                                    pickzone      NVARCHAR(20) NULL  DEFAULT(''),
--                                    modedesc      NVARCHAR(250) NULL  DEFAULT(''), 
--                                    nooforder     INT  NULL DEFAULT(0),
--                                    showsalesman  NVARCHAR(1) NULL  DEFAULT(''),
--                                    salesman      NVARCHAR(60) NULL  DEFAULT(''), 
--                                    showcourier   NVARCHAR(10) NULL  DEFAULT(''),
--                                    shipperkey    NVARCHAR(30) NULL  DEFAULT(''), 
--                                    showloadkeybarcode      NVARCHAR(10) NULL  DEFAULT(''),
--                                    OrderCount              NVARCHAR(10) NULL ,
--                                    RptMode                 NVARCHAR(10) NULL ,
--                                    ReGen                   NVARCHAR(10) NULL,
--                                    updatepick              NVARCHAR(10) NULL,
--                                    Zonetype                NVARCHAR(10) NULL
--                                    )
       

--CREATE TABLE #TMPBatchTASKSUM06SRPT (
--                                    loadkey       NVARCHAR(20) NULL  DEFAULT(''),
--                                    noofsku       INT  NULL DEFAULT(0),
--                                    qty           INT  NULL DEFAULT(0),
--                                    pickzone      NVARCHAR(20) NULL  DEFAULT('')
--                                    )
      
--IF  @c_RptType = 'H'
--BEGIN

    IF @c_Mode NOT IN('1','4','5','9')
    BEGIN 
       SELECT @n_Continue = 3  
       SELECT @n_Err = 63200  
       SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Mode. The value must be 1,4,5,9 (isp_batching_task_summary_06)' 
       GOTO Quit
    END

    SELECT TOP 1 @c_Storerkey = Storerkey
                ,@c_Facility = Facility
    FROM ORDERS (NOLOCK)
    WHERE Loadkey = @c_Loadkey      
    
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
                         WHERE LPD.Loadkey = @c_Loadkey 
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
         --KY01 S
         --SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.Descr) + ','  
         --FROM ORDERS O (NOLOCK)  
         --JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
         --JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
         --JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
         --WHERE LPD.Loadkey = @c_Loadkey  
         --GROUP BY LOC.Descr  
         --ORDER BY LOC.Descr  

         SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.Descr)
                                     FROM ORDERS O (NOLOCK)  
                                     JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                                     JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
                                     JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
                                     WHERE LPD.Loadkey = @c_Loadkey  
                                     GROUP BY LOC.Descr  
                                     ORDER BY LOC.Descr FOR XML PATH('')),1,1,'' ) + ','
         --KY01 E
      END
      ELSE
      BEGIN
         --KY01 S
         --SELECT @c_ZoneList = @c_ZoneList + RTRIM(Loc.PickZone) + ','  
         --FROM ORDERS O (NOLOCK)  
         --JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
         --JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
         --JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
         --WHERE LPD.Loadkey = @c_Loadkey  
         --GROUP BY LOC.PickZone  
         --ORDER BY LOC.PickZone      
         
         SELECT @c_ZoneList = STUFF((SELECT ',' + RTRIM(Loc.PickZone)
                                     FROM ORDERS O (NOLOCK)  
                                     JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
                                     JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
                                     JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
                                     WHERE LPD.Loadkey = @c_Loadkey  
                                     GROUP BY LOC.PickZone  
                                     ORDER BY LOC.PickZone FOR XML PATH('')),1,1,'' ) + ','
         --KY01 E      
      END
      
      IF ISNULL(@c_ZoneList,'') <> ''
      BEGIN
          SET @c_ZoneList = LEFT(@c_ZoneList, LEN(RTRIM(@c_ZoneList)) - 1)
          SET @c_PickZone = @c_ZoneList
      END
    END       

   IF @c_RptType = 'H'
   BEGIN
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
          
        IF ISNULL(@c_PickByVP,'') = '1'
        BEGIN
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
                  SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to Update Loadplan (isp_batching_task_summary_06)' 
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
         @c_LoadKey     = @c_LoadKey
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

END
    --IF @c_RptType = 'S'
    --BEGIN
    --   GOTO Sub_Rpt
    --END 
 --IF @c_RptType='H'
 --BEGIN

IF @c_RptType = 'H' GOTO TYPE_H
IF @c_RptType = 'S' GOTO TYPE_S


TYPE_H:
    IF @c_OrderBatchBylocdescr = '1'  
    BEGIN
            INSERT INTO #TMPBTBYPZ
            (
                taskbatchno,
                Orderkey,
                pickzone,
                Zonetype
            )
            SELECT DISTINCT PT.TaskBatchNo AS TaskBatchNo,PT.Orderkey AS orderkey,LOC.Descr,CASE WHEN LOC.Descr ='AGV' THEN 'AGV' ELSE 'NOAGV' END AS Zonetype
            FROM ORDERS O (NOLOCK)  
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
            JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
            JOIN dbo.PackTask PT WITH (NOLOCK) ON PT.Orderkey=o.OrderKey
            WHERE LPD.Loadkey = @c_Loadkey  
            AND LOC.Descr IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
            AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
            GROUP BY PT.TaskBatchNo,LOC.Descr,PT.Orderkey,CASE WHEN LOC.Descr ='AGV' THEN 'AGV' ELSE 'NOAGV' END 
            ORDER BY PT.TaskBatchNo,LOC.Descr,PT.Orderkey,CASE WHEN LOC.Descr ='AGV' THEN 'AGV' ELSE 'NOAGV' END 

           INSERT INTO #TMPBTOHSalesman
           (
               taskbatchno,
               Zonetype,
               OHSalesman
           )
            SELECT DISTINCT TPLZ.TaskBatchNo AS taskbatchno,TPLZ.Zonetype AS zonetype ,ISNULL(STUFF( (SELECT DISTINCT ',' + oh.salesman 
                                                                                             FROM #TMPBTBYPZ TPOD WITH (NOLOCK)
                                                                                             --JOIN dbo.PackTask PT WITH (NOLOCK) ON PT.TaskBatchNo = TPOD.TaskBatchNo
                                                                                             JOIN LOC L WITH (NOLOCK) ON L.PickZone = TPOD.PickZone  
                                                                                             JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = TPOD.Orderkey 
                                                                                             WHERE TPOD.TaskBatchNo = TPLZ.TaskBatchNo
                                                                                             -- AND   TPOD.PickZone = TPLZ.PickZone
                                                                                             AND   TPOD.Zonetype = TPLZ.Zonetype
                                                                                             --AND TPOD.orderkey = TPLZ.orderkey
                                                                                             FOR XML PATH ('')
                                                                                             ),1,1,'' ),'') AS OHSalesman
            FROM #TMPBTBYPZ TPLZ 
            GROUP BY TPLZ.TaskBatchNo,TPLZ.Zonetype
            ORDER BY TPLZ.TaskBatchNo,TPLZ.Zonetype

SELECT 1
      --INSERT INTO #TMPBatchTASKSUM06
      --(
      --    taskbatchn,
      --    notes,
      --    loadkey,
      --    noofsku,
      --    qty,
      --    pickzone,
      --    modedesc,
      --    nooforder,
      --    showsalesman,
      --    salesman,
      --    showcourier,
      --    shipperkey,
      --    showloadkeybarcode
      --)

       SELECT PT.TaskBatchNo AS TaskBatchNo, 
              PD.Notes AS notes, 
              LP.Loadkey AS loadkey, 
              COUNT(DISTINCT PD.Sku) AS NoOfSku,
              SUM(PD.Qty) AS Qty,
              L.Descr AS Pickzone,
              CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                   CL.Long
              ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,
              COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,
              ISNULL(CL1.Short,'N') AS ShowSalesman,  
              CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Salesman,  
              ISNULL(CL2.Short,'N') AS showcourier,  
              CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Shipperkey,  
              ISNULL(CL3.Short,'N') AS ShowLoadkeyBarcode,   
              @c_OrderCount AS OrderCount,
              --@c_Pickzone AS 
              @c_Mode AS RptMode,
              @c_ReGen AS ReGen,
              @c_updatepick AS updatepick,
              CASE WHEN L.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END AS Zonetype     --CS01
       --INTO #TMPBatchTASKSUM06
       FROM LOADPLANDETAIL LP (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
       LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
       LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman' 
                                       AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL1.Short,'') <> 'N')  
       LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier' 
                                       AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL2.Short,'') <> 'N')  
       LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowLoadkeyBarcode' 
                                       AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL3.Short,'') <> 'N')  
       WHERE LP.Loadkey = @c_Loadkey
       AND L.Descr IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
       GROUP BY PT.TaskBatchNo, 
                PD.Notes, 
                LP.Loadkey,
                L.Descr,
                CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                   CL.Long
                ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END,
                ISNULL(CL1.Short,'N'),  
                ISNULL(CL2.Short,'N'),  
                ISNULL(CL3.Short,'N'),CASE WHEN L.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END    --CS01   
       ORDER BY PT.TaskBatchNo,L.Descr, PD.NOTES --,CASE WHEN L.PickZone ='AGV' THEN 0 ELSE 1 END     --CS01   
    END               
    ELSE
    BEGIN
            INSERT INTO #TMPBTBYPZ
            (
                taskbatchno,
                Orderkey,
                pickzone,
                Zonetype
            )
            SELECT DISTINCT PT.TaskBatchNo AS TaskBatchNo,PT.Orderkey AS orderkey,LOC.pickzone,CASE WHEN Loc.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END AS Zonetype--,o.Salesman
            FROM ORDERS O (NOLOCK)  
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey       
            JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
            JOIN Loadplandetail LPD (NOLOCK) ON LPD.OrderKey = O.orderkey   
            JOIN dbo.PackTask PT WITH (NOLOCK) ON PT.Orderkey=o.OrderKey
            WHERE LPD.Loadkey = @c_Loadkey  
            AND Loc.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
            AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
            GROUP BY PT.TaskBatchNo,LOC.pickzone,PT.Orderkey,CASE WHEN Loc.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END 
            ORDER BY PT.TaskBatchNo,LOC.pickzone,PT.Orderkey,CASE WHEN Loc.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END 

           INSERT INTO #TMPBTOHSalesman
           (
               taskbatchno,
               Zonetype,
               OHSalesman
           )

            SELECT DISTINCT TPLZ.TaskBatchNo AS taskbatchno,TPLZ.Zonetype AS zonetype ,ISNULL(STUFF( (SELECT DISTINCT ',' + oh.salesman 
                                                   FROM #TMPBTBYPZ TPOD WITH (NOLOCK)
                                                   --JOIN dbo.PackTask PT WITH (NOLOCK) ON PT.TaskBatchNo = TPOD.TaskBatchNo
                                                   JOIN LOC L WITH (NOLOCK) ON L.PickZone = TPOD.PickZone  
                                                   JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = TPOD.Orderkey 
                                                   WHERE TPOD.TaskBatchNo = TPLZ.TaskBatchNo
                                                   -- AND   TPOD.PickZone = TPLZ.PickZone
                                                   AND   TPOD.Zonetype = TPLZ.Zonetype
                                                   --AND TPOD.orderkey = TPLZ.orderkey
                                                   FOR XML PATH ('')
                                                   ),1,1,'' ),'') AS OHSalesman
            FROM #TMPBTBYPZ TPLZ GROUP BY TPLZ.TaskBatchNo,TPLZ.Zonetype
            ORDER BY TPLZ.TaskBatchNo,TPLZ.Zonetype


      --       INSERT INTO #TMPBatchTASKSUM06
      --(
      --    taskbatchn,
      --    notes,
      --    loadkey,
      --    noofsku,
      --    qty,
      --    pickzone,
      --    modedesc,
      --    nooforder,
      --    showsalesman,
      --    salesman,
      --    showcourier,
      --    shipperkey,
      --    showloadkeybarcode
      --)
       SELECT PT.TaskBatchNo AS TaskBatchNo, 
              PD.Notes AS notes, 
              LP.Loadkey AS loadkey, 
              COUNT(DISTINCT PD.Sku) AS NoOfSku,
              SUM(PD.Qty) AS Qty,
              L.PickZone AS Pickzone,
              CASE WHEN ISNULL(CL.Long,'') <> '' THEN
                   CL.Long
              ELSE RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) END AS ModeDesc,
              COUNT(DISTINCT PD.Orderkey) AS NoOfOrder,
              ISNULL(CL1.Short,'N') AS ShowSalesman,  
              TSM.OHSalesman AS salesman,--ISNULL(Orders.Salesman,'') AS salesman,--CASE WHEN ISNULL(CL1.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Salesman,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Salesman,   
              ISNULL(CL2.Short,'N') AS ShowSalesman,  
              CASE WHEN ISNULL(CL2.Short,'N') = 'N' THEN '' ELSE (SELECT MAX(ISNULL(Orders.Shipperkey,'')) FROM Orders (NOLOCK) WHERE Orders.Loadkey = LP.Loadkey) END AS Shipperkey,   
              ISNULL(CL3.Short,'N') AS ShowLoadkeyBarcode,
              @c_OrderCount AS OrderCount,
              --@c_Pickzone AS 
              @c_Mode AS RptMode,
              @c_ReGen AS ReGen,
              @c_updatepick AS updatepick,
              CASE WHEN L.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END AS Zonetype     --CS01  
       --INTO #TMPBatchTASKSUM06
       FROM LOADPLANDETAIL LP (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
       JOIN ORDERS (NOLOCK) ON orders.orderkey=LP.OrderKey
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
       LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
       LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman' 
                                       AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL1.Short,'') <> 'N')  
       LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier' 
                                       AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL2.Short,'') <> 'N') 
       LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowLoadkeyBarcode' 
                                       AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL3.Short,'') <> 'N')  
       JOIN #TMPBTOHSalesman TSM ON TSM.taskbatchno=PT.TaskBatchNo AND TSM.zonetype = CASE WHEN L.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END
       WHERE LP.Loadkey = @c_Loadkey
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
                CASE WHEN L.PickZone ='AGV' THEN 'AGV' ELSE 'NOAGV' END     ,TSM.OHSalesman--ISNULL(Orders.Salesman,'')  --CS01   
       ORDER BY PT.TaskBatchNo,L.PickZone, PD.NOTES ,CASE WHEN L.PickZone ='AGV' THEN 0 ELSE 1 END     --CS01      
    END

       --INSERT INTO #TMPBatchTASKSUM06SRPT
       --(
       --    loadkey,
       --    noofsku,
       --    qty,
       --    pickzone
       --)
       --       SELECT  Loadkey, 
       --      COUNT(DISTINCT NoOfSku) AS NoOfSku,
       --       SUM(Qty) AS Qty,
       --       PickZone
       --       FROM #TMPBatchTASKSUM06
       --       WHERE Loadkey = @c_Loadkey
       --       GROUP BY  Loadkey, 
       --      -- SUM(PD.Qty), 
       --       PickZone



--TYPE_H: 
--SELECT * FROM #TMPBatchTASKSUM06
--WHERE loadkey =@c_Loadkey
--ORDER BY pickzone,notes



GOTO QUIT

TYPE_S:
 IF @c_OrderBatchBylocdescr = '1'  
 BEGIN


      SELECT  LP.Loadkey AS loadkey, 
              COUNT(DISTINCT PD.Sku) AS NoOfSku,
              SUM(PD.Qty) AS Qty,
              L.Descr AS Pickzone
       FROM LOADPLANDETAIL LP (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
       LEFT JOIN CODELKUP CL ON RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = CL.Code AND CL.Listname = 'BATCHMODE' 
       LEFT JOIN Codelkup CL1 (NOLOCK) ON (PD.Storerkey = CL1.Storerkey AND CL1.Code = 'ShowSalesman' 
                                       AND CL1.Listname = 'REPORTCFG' AND CL1.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL1.Short,'') <> 'N')  
       LEFT JOIN Codelkup CL2 (NOLOCK) ON (PD.Storerkey = CL2.Storerkey AND CL2.Code = 'ShowCourier' 
                                       AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL2.Short,'') <> 'N')  
       LEFT JOIN Codelkup CL3 (NOLOCK) ON (PD.Storerkey = CL3.Storerkey AND CL3.Code = 'ShowLoadkeyBarcode' 
                                       AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_batching_task_summary_06' AND ISNULL(CL3.Short,'') <> 'N')  
       WHERE LP.Loadkey = @c_Loadkey
      -- AND L.Descr IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
       
       GROUP BY PT.TaskBatchNo, 
                PD.Notes, 
                LP.Loadkey,
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
    IF @c_ZoneType ='AGV'
    BEGIN
      SELECT  LP.Loadkey, 
              COUNT(DISTINCT PD.Sku) AS NoOfSku,
              SUM(PD.Qty) AS Qty,
              L.PickZone
  FROM LOADPLANDETAIL LP (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
  WHERE LP.Loadkey = @c_Loadkey
  AND PT.TaskBatchNo = @c_taskbatchno
      -- AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
       AND L.PickZone ='AGV'
       GROUP BY  LP.Loadkey, 
             -- SUM(PD.Qty), 
              L.PickZone
  END
  ELSE
  BEGIN
    SELECT  LP.Loadkey, 
              COUNT(DISTINCT PD.Sku) AS NoOfSku,
              SUM(PD.Qty) AS Qty,
              L.PickZone
  FROM LOADPLANDETAIL LP (NOLOCK)
       JOIN PICKDETAIL PD (NOLOCK) ON LP.orderkey = PD.OrderKey
       JOIN LOC L (NOLOCK) ON PD.Loc = L.Loc
       JOIN PACKTASK PT (NOLOCK) ON PD.Orderkey = PT.Orderkey
  WHERE LP.Loadkey = @c_Loadkey
      -- AND L.Pickzone IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',',@c_PickZone)) 
       AND RIGHT(RTRIM(ISNULL(PD.Notes,'')),1) = @c_Mode
       AND L.PickZone not IN ('AGV')
       AND PT.TaskBatchNo = @c_taskbatchno
       GROUP BY  LP.Loadkey, 
             -- SUM(PD.Qty), 
              L.PickZone
  END
END

   GOTO QUIT 
    
Quit:
 

--DROP TABLE #TMPBatchTASKSUM06
--DROP TABLE #TMPBatchTASKSUM06SRPT

DROP TABLE #TMPBTBYPZ
DROP TABLE #TMPBTOHSalesman


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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_batching_task_summary_06'  
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