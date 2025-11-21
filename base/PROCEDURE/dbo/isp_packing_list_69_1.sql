SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_Packing_List_69_1                                   */  
/* Creation Date: 25-SEP-2019                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:WMS-10695 - Copied from isp_GetPickSlipOrders85_1            */  
/*        :                                                             */  
/* Called By:r_dw_print_packlist_11_1    (ECOM)                         */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */
/* 2021-01-27   WLChooi   1.1 WMS-16114 - Get MaxLineNo from Codelkup   */  
/*                            (WL01)                                    */
/* 2021-03-05   CSCHONG   1.2 WMS-16402 - revised field logic (CS02)    */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Packing_List_69_1]  
            @c_PickSlipNo     NVARCHAR(10)
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
         , @b_Success         INT  
         , @n_Err             INT  
         , @c_Errmsg          NVARCHAR(255)  
  
         , @n_NoOfReqPSlip    INT  
         , @c_Orderkey        NVARCHAR(10)  
    --     , @c_PickSlipNo      NVARCHAR(10)  
         , @c_PickHeaderKey   NVARCHAR(10)  
         , @c_Storerkey       NVARCHAR(15)  
  
         , @c_AutoScanIn      NVARCHAR(10)  
         , @c_Facility        NVARCHAR(5)  
         , @c_Logo            NVARCHAR(50)  
         , @n_MaxLine         INT  
         , @n_CntRec          INT  
         , @c_MaxPSlipno      NVARCHAR(10)  
         , @n_LastPage        INT  
         , @n_ReqLine         INT  
         , @c_JCLONG          NVARCHAR(255)  
         , @c_RNotes          NVARCHAR(255)  
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_PrnQty          INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @n_Page            INT
         , @n_getPageno       INT
         , @c_recgroup        INT
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue  = 1  
   SET @b_Success   = 1  
   SET @n_Err       = 0  
   SET @c_Errmsg    = ''  
   SET @c_Logo      = ''  
   SET @n_MaxLine   = 9  
   SET @n_CntRec    = 1  
   SET @n_LastPage  = 0  
   SET @n_ReqLine   = 1  
   --SET @n_MaxLineno = 8   --WL01
   SET @n_PrnQty    = 1
   SET @n_MaxId     = 1
   SET @n_MaxRec    = 1
   SET @n_CurrentRec= 1
   SET @n_Page      = 1
   SET @n_getPageno = 1
   SET @c_recgroup  = 1

   --Check ECOM orders
   SELECT TOP 1 @c_ecomflag  = LTRIM(RTRIM(ISNULL(ORDERS.TYPE,'')))
              , @c_Storerkey = ORDERS.StorerKey   --WL01
   FROM ORDERS (NOLOCK)
   JOIN PICKHEADER (NOLOCK) ON PICKHEADER.ORDERKEY = ORDERS.ORDERKEY
   WHERE PICKHEADER.Pickheaderkey = @c_PickSlipNo
   
   IF (@c_ecomflag <> 'ECOM')
     GOTO QUIT_RESULT

   --WL01 S
   SELECT @n_MaxLineno = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 7 END
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'REPORTCFG' AND CL.Code = 'MaxLineNo'
   AND CL.Long = 'r_dw_packing_list_69' AND CL.Code2 = 'r_dw_packing_list_69'
   AND CL.Storerkey = @c_Storerkey
   
   IF ISNULL(@n_MaxLineno,0) = 0
   BEGIN
      SET @n_MaxLineno = 7
   END
   --WL01 E
  
   CREATE TABLE #TMP_PCK_1  
      ( Loadkey      NVARCHAR(10)   NOT NULL  
      , Orderkey     NVARCHAR(10)   NOT NULL  
      , PickSlipNo   NVARCHAR(10)   NOT NULL  
      , Storerkey    NVARCHAR(15)   NOT NULL    
      )  
  
   CREATE TABLE #TMP_PCK_1_101  
      ( rowid           int NOT NULL identity(1,1) PRIMARY KEY
      , PickSlipNo      NVARCHAR(10)   NOT NULL  
      , Contact1        NVARCHAR(45)   NULL  
      , ODUDF03         NVARCHAR(80)   NULL  
      , Loadkey         NVARCHAR(10)   NOT NULL  
      , Orderkey        NVARCHAR(10)   NOT NULL  
      , DelDate         DATETIME
      , SHIPPERKEY      NVARCHAR(20)   NULL    
      , ExternOrderkey  NVARCHAR(50)   NULL  
      , Notes           NVARCHAR(255)  NULL  
      , Loc             NVARCHAR(20)   NULL  
      , Storerkey       NVARCHAR(15)   NOT NULL  
      , SKU             NVARCHAR(20)   NULL  
      , CUDF01          NVARCHAR(255)  NULL  
      , CUDF02          NVARCHAR(255)  NULL  
      , Qty             INT  NULL
      , ODNotes2        NVARCHAR(255)  NULL  
      , Pageno          INT  
      , OIPlatform      NVARCHAR(40)  
      , CarrierCharges  FLOAT
      )
      
      CREATE TABLE #TMP_PCK_1_101_1  
      ( rowid           int NOT NULL identity(1,1) PRIMARY KEY
      , PickSlipNo      NVARCHAR(10)   NOT NULL  
      , Contact1        NVARCHAR(45)   NULL  
      , ODUDF03         NVARCHAR(80)   NULL  
      , Loadkey         NVARCHAR(10)   NOT NULL  
      , Orderkey        NVARCHAR(10)   NOT NULL  
      , DelDate         DATETIME
      , SHIPPERKEY      NVARCHAR(20)   NULL    
      , ExternOrderkey  NVARCHAR(50)   NULL  
      , Notes           NVARCHAR(255)  NULL  
      , Loc             NVARCHAR(20)   NULL  
      , Storerkey       NVARCHAR(15)   NOT NULL  
      , SKU             NVARCHAR(20)   NULL  
      , CUDF01          NVARCHAR(255)  NULL  
      , CUDF02          NVARCHAR(255)  NULL  
      , Qty             INT  NULL
      , ODNotes2        NVARCHAR(255)  NULL  
      , Pageno          INT  
      , OIPlatform      NVARCHAR(40)  
      , CarrierCharges  FLOAT
      , recgroup        INT NULL
      , ShowNo          NVARCHAR(1)
      )    
  
      --SET @c_Facility = ''  
      --SELECT @c_Facility = Facility  
      --FROM LOADPLAN WITH (NOLOCK)  
      --WHERE Loadkey = @c_Loadkey  
  
   INSERT INTO #TMP_PCK_1  
      ( Loadkey  
      , Orderkey  
      , PickSlipNo  
      , Storerkey  
      )  
  
   SELECT DISTINCT  
          LOADPLANDETAIL.Loadkey  
         ,LOADPLANDETAIL.Orderkey  
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')  
         ,ORDERS.Storerkey   
   FROM LOADPLANDETAIL  WITH (NOLOCK)  
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
   JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)  
                           --    AND(LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)   
   WHERE PICKHEADER.Pickheaderkey = @c_PickSlipNo
   --WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey  
   GROUP BY LOADPLANDETAIL.Loadkey  
         ,  LOADPLANDETAIL.Orderkey  
         ,  ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')  
         ,  ORDERS.Storerkey  
  
   BEGIN TRAN  
   -- Uses PickType as a Printed Flag  
   UPDATE PICKHEADER WITH (ROWLOCK)  
   SET PickType = '1'  
      ,EditWho = SUSER_NAME()  
      ,EditDate= GETDATE()  
      ,TrafficCop = NULL  
   FROM PICKHEADER  
   JOIN #TMP_PCK_1 ON (PICKHEADER.PickHeaderKey = #TMP_PCK_1.PickSlipNo)  
   WHERE #TMP_PCK_1.PickSlipNo <> ''  
  
   SET @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SET @n_Continue = 3  
      GOTO QUIT_SP  
   END  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   --SET @n_NoOfReqPSlip  = 0  
  
   --SELECT @n_NoOfReqPSlip = COUNT(1)  
   --FROM #TMP_PCK_1  
   --WHERE PickSlipNo = ''  
  
  
   --IF @n_NoOfReqPSlip > 0  
   --BEGIN  
   --   EXECUTE nspg_GetKey  
   --           'PICKSLIP'  
   --         , 9  
   --         , @c_PickSlipNo   OUTPUT  
   --         , @b_Success      OUTPUT  
   --         , @n_Err          OUTPUT  
   --         , @c_Errmsg       OUTPUT  
   --         , 0  
   --         , @n_NoOfReqPSlip  
  
   --   IF @b_success <> 1  
   --   BEGIN  
   --      SET @n_Continue = 3  
   --      GOTO QUIT_SP  
   --   END  
  
   --   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --   SELECT Orderkey  
   --   FROM #TMP_PCK_1  
   --   WHERE PickSlipNo = ''  
   --   ORDER BY Orderkey  
  
   --   OPEN CUR_PSLIP  
  
   --   FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey  
  
   --   WHILE @@FETCH_STATUS <> -1  
   --   BEGIN  
  
   --      SET @c_PickHeaderKey = 'P' + @c_PickSlipNo  
  
   --      BEGIN TRAN  
  
   --      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
   --      VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', NULL)  
  
   --      SET @n_err = @@ERROR  
   --      IF @n_err <> 0  
   --      BEGIN  
   --         SET @n_Continue = 3  
   --         GOTO QUIT_SP  
   --      END  
  
   --      UPDATE #TMP_PCK_1  
   --      SET PickSlipNo= @c_PickHeaderKey  
   --      WHERE Loadkey = @c_Loadkey  
   --      AND Orderkey  = @c_Orderkey  
  
   --      WHILE @@TRANCOUNT > 0  
   --      BEGIN  
   --         COMMIT TRAN  
   --      END  
  
   --      SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)  
   --      FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey  
   --   END  
   --   CLOSE CUR_PSLIP  
   --   DEALLOCATE CUR_PSLIP  
   --END  
  
   --/*CS01 Start*/  
  
  
   --DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --SELECT PickSlipNo  
   --      ,OrderKey  
   --      ,Storerkey  
   --FROM #TMP_PCK_1  
   --ORDER BY PickSlipNo  
  
   --OPEN CUR_PSNO  
  
   --FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo  
   --                             ,@c_Orderkey  
   --                             ,@c_Storerkey  
   --WHILE @@FETCH_STATUS <> -1  
   --BEGIN  
   --   SET @c_AutoScanIn = '0'  
   --   EXEC nspGetRight  
   --         @c_Facility   = @c_Facility  
   --      ,  @c_StorerKey  = @c_StorerKey  
   --      ,  @c_sku        = ''  
   --      ,  @c_ConfigKey  = 'AutoScanIn'  
   --      ,  @b_Success    = @b_Success    OUTPUT  
   --      ,  @c_authority  = @c_AutoScanIn OUTPUT  
   --      ,  @n_err        = @n_err        OUTPUT  
   --      ,  @c_errmsg     = @c_errmsg     OUTPUT  
  
   --   IF @b_Success = 0  
   --   BEGIN  
   --  SET @n_Continue = 3  
   --      GOTO QUIT_SP  
   --   END  
  
   --   BEGIN TRAN  
   --   IF @c_AutoScanIn = '1'  
   --   BEGIN  
   --      IF NOT EXISTS (SELECT 1  
   --                     FROM PICKINGINFO WITH (NOLOCK)  
   --                     WHERE PickSlipNo = @c_PickSlipNo  
   --                     )  
   --      BEGIN  
   --         INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
   --         VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)  
  
   --         SET @n_err = @@ERROR  
   --         IF @n_err <> 0  
   --         BEGIN  
   --            SET @n_Continue = 3  
   --            GOTO QUIT_SP  
   --         END  
   --      END  
   --   END  
  
   --   WHILE @@TRANCOUNT > 0  
   --   BEGIN  
   --      COMMIT TRAN  
   --   END  
   --   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo  
   --                                ,@c_Orderkey  
   --                                ,@c_Storerkey  
   --END  
   --CLOSE CUR_PSNO  
   --DEALLOCATE CUR_PSNO  
  
   /*CS01 END*/  
  
QUIT_SP:  
  
   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)  
   BEGIN  
      CLOSE CUR_PSLIP  
      DEALLOCATE CUR_PSLIP  
   END  
  
   IF @n_Continue = 3  
   BEGIN  
      IF @@TRANCOUNT > 0  
      BEGIN  
         ROLLBACK TRAN  
      END  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
   INSERT INTO #TMP_PCK_1_101  
              ( PickSlipNo  
              , Contact1  
              , ODUDF03  
              , Loadkey  
              , Orderkey  
              , DelDate  
              , SHIPPERKEY  
              , ExternOrderkey  
              , Notes  
              , Loc  
              , Storerkey  
              , SKU  
              , CUDF01  
              , CUDF02  
              , Qty  
              , ODNotes2  
              , Pageno  
              , OIPlatform
              , CarrierCharges
              )  
   SELECT #TMP_PCK_1.PickSlipNo  
         ,Contact1 = ISNULL(RTRIM(ORDERS.c_contact1),'')  
         ,ODUDF03 = ISNULL(RTRIM(OD.Userdefine03),'')
         ,#TMP_PCK_1.Loadkey  
         ,#TMP_PCK_1.Orderkey  
         ,OrdDate   = ORDERS.DeliveryDate  
         ,SHIPPERKEY   = ORDERS.ShipperKey  
         ,ExternOrderkey = ORDERS.EXTERNORDERKEY
         ,Notes   = ISNULL(RTRIM(OD.Notes),'')  
         ,PICKDETAIL.Loc  
         ,PICKDETAIL.Storerkey  
         ,SKU = PICKDETAIL.sku
         ,CUDF01 = ISNULL(CL2.UDF01,'')  
         ,CUDF02 = ISNULL(CL2.UDF02,'')  
         ,Qty = ISNULL(SUM(PICKDETAIL.QTY),0)--ISNULL(SUM(OD.ORIGINALQTY),0)    --(CS01)
         ,ODNotes2 =ISNULL(RTRIM(OD.Notes2),'')  
         ,pageno = 1  
         ,OIPlatform = ISNULL(CL1.UDF01,'')--ISNULL(OI.PLATFORM,'')    --CS01
         ,CarrierCharges = OI.CarrierCharges
   FROM #TMP_PCK_1  
   JOIN STORER     WITH (NOLOCK) ON (#TMP_PCK_1.Storerkey = STORER.Storerkey)  
   JOIN ORDERS     WITH (NOLOCK) ON (#TMP_PCK_1.Orderkey  = ORDERS.Orderkey)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.orderkey = ORDERS.Orderkey  
   JOIN PICKDETAIL WITH (NOLOCK) ON (OD.Orderkey    = PICKDETAIL.Orderkey  
                                     AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber
                            AND OD.SKU = PICKDETAIL.SKU)  
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                 AND(PICKDETAIL.Sku       = SKU.Sku)  
   LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey  
   --LEFT JOIN CODELKUP CL1 (NOLOCK) ON ORDERS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECLOGISTP'       --(CS01)
   LEFT JOIN CODELKUP  CL1 (NOLOCK) ON OI.PLATFORM = CL1.CODE AND OD.LOTTABLE02 = CL1.CODE2                  --(CS01)
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON RTRIM(ORDERS.SHIPPERKEY) =  CL2.CODE AND CL2.LISTNAME = 'ECDLMODE'  
                                     AND CL2.STORERKEY = ORDERS.STORERKEY AND CL2.code2=''                   --(CS02)
   WHERE #TMP_PCK_1.PickSlipNo <> '' 
   --AND ORDERS.STATUS ='3'                  --CS01
   AND ORDERS.TYPE = 'ECOM' 
   GROUP BY #TMP_PCK_1.PickSlipNo  
         ,  ISNULL(RTRIM(ORDERS.c_contact1),'')  
         ,  ISNULL(RTRIM(OD.Userdefine03),'')
         ,  #TMP_PCK_1.Orderkey  
         ,  #TMP_PCK_1.Loadkey  
         ,  ORDERS.DeliveryDate 
         ,  ORDERS.ShipperKey    
         ,  ORDERS.EXTERNORDERKEY 
         ,  ISNULL(RTRIM(OD.Notes),'')  
         ,  PICKDETAIL.Loc  
         ,  PICKDETAIL.Storerkey  
         ,  PICKDETAIL.sku  
         ,  ISNULL(CL2.UDF01,'')   
         ,  ISNULL(CL2.UDF02,'')   
         ,  ISNULL(RTRIM(OD.Notes2),'')  
         ,  OI.CarrierCharges 
       ,  ISNULL(CL1.UDF01,'')--ISNULL(OI.PLATFORM,'')    --CS01  
   ORDER BY #TMP_PCK_1.PickSlipNo  
           ,#TMP_PCK_1.Orderkey 
         ,PICKDETAIL.Loc   

  DECLARE CUR_psno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT DISTINCT PICKSLIPNO,ORDERKEY
  FROM #TMP_PCK_1_101
  --WHERE LOADKEY = @c_Loadkey

  OPEN CUR_psno

  FETCH NEXT FROM CUR_psno INTO @c_Pickslipno, @c_Orderkey
  WHILE @@FETCH_STATUS <> -1
  BEGIN
      INSERT INTO #TMP_PCK_1_101_1
      (PickSlipNo, Contact1, ODUDF03, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey, Notes, Loc  
       , Storerkey, SKU, CUDF01, CUDF02, Qty, ODNotes2, Pageno, OIPlatform, CarrierCharges, RECGROUP, ShowNo)
      SELECT PickSlipNo, Contact1, ODUDF03, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey, Notes, Loc  
       , Storerkey, SKU, CUDF01, CUDF02, Qty, ODNotes2, Pageno, OIPlatform, CarrierCharges,(Row_Number() OVER (PARTITION BY PickSlipNo,ORDERKEY  ORDER BY PickSlipNo,Orderkey,Loc Asc)-1)/@n_MaxLineno+1 AS recgroup
       ,'Y'
      FROM #TMP_PCK_1_101 WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey

  select @n_MaxRec = COUNT(rowid) from #TMP_PCK_1_101 WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey

  SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

  WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
  BEGIN
      INSERT INTO #TMP_PCK_1_101_1
      (PickSlipNo, Contact1, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey  
       , Storerkey, CUDF01, CUDF02, Pageno, OIPlatform, CarrierCharges, RECGROUP,ShowNo)
      SELECT TOP 1 PickSlipNo, Contact1, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey 
       , Storerkey, CUDF01, CUDF02, Pageno, OIPlatform, CarrierCharges, RECGROUP,'N'
       FROM #TMP_PCK_1_101_1 WHERE PickSlipNo = @c_Pickslipno AND ORDERKEY =  @c_Orderkey
       ORDER BY ROWID DESC

       SET @n_CurrentRec = @n_CurrentRec + 1
  END

  SET @n_MaxRec = 0
  SET @n_CurrentRec = 0

  FETCH NEXT FROM CUR_psno INTO @c_Pickslipno, @c_Orderkey
  END

  
  select PickSlipNo, Contact1, ODUDF03, Loadkey, Orderkey, DelDate, SHIPPERKEY, ExternOrderkey, Notes, Loc  
       , Storerkey, SKU, CUDF01, CUDF02, Qty, ODNotes2, Pageno, OIPlatform, CarrierCharges,ShowNo from #TMP_PCK_1_101_1
  ORDER BY pickslipno, orderkey, CASE WHEN ISNULL(sku,'') = '' THEN 1 ELSE 0 END
  
  QUIT_RESULT:       --WL01
END -- procedure


GO