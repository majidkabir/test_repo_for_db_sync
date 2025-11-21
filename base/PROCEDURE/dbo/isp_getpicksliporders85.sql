SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_GetPickSlipOrders85                                 */  
/* Creation Date: 05-DEC-2018                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:WMS-7192- [TW] POI New PickSlip RCM Report                   */  
/*        :                                                             */  
/* Called By:r_dw_print_pickorder85                                     */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 08-JAN-2019  CSCHONG   1.0 WMS-7512-revised field logic (CS01)       */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPickSlipOrders85]  
            @c_Loadkey     NVARCHAR(10)  
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
         , @c_PickSlipNo      NVARCHAR(10)  
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
  
   SET @n_StartTCnt= @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @b_Success  = 1  
   SET @n_Err      = 0  
   SET @c_Errmsg   = ''  
   SET @c_Logo     = ''  
   SET @n_MaxLine  = 9  
   SET @n_CntRec   = 1  
   SET @n_LastPage = 0  
   SET @n_ReqLine  = 1  
  
   CREATE TABLE #TMP_PCK  
      ( Loadkey      NVARCHAR(10)   NOT NULL  
      , Orderkey     NVARCHAR(10)   NOT NULL  
      , PickSlipNo   NVARCHAR(10)   NOT NULL  
      , Storerkey    NVARCHAR(15)   NOT NULL    
      )  
  
   CREATE TABLE #TMP_PCK85  
      ( PickSlipNo      NVARCHAR(10)   NOT NULL  
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
      , Qty             INT  
      , ODNotes2        NVARCHAR(255)  NULL  
      , Pageno          INT  
      , OIPlatform      NVARCHAR(40)  
	  , CarrierCharges  FLOAT 
      )  
  
      SET @c_Facility = ''  
      SELECT @c_Facility = Facility  
      FROM LOADPLAN WITH (NOLOCK)  
      WHERE Loadkey = @c_Loadkey  
  
   INSERT INTO #TMP_PCK  
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
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)  
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)  
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey  
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
   JOIN #TMP_PCK ON (PICKHEADER.PickHeaderKey = #TMP_PCK.PickSlipNo)  
   WHERE #TMP_PCK.PickSlipNo <> ''  
  
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
  
   SET @n_NoOfReqPSlip  = 0  
  
   SELECT @n_NoOfReqPSlip = COUNT(1)  
   FROM #TMP_PCK  
   WHERE PickSlipNo = ''  
  
  
   IF @n_NoOfReqPSlip > 0  
   BEGIN  
      EXECUTE nspg_GetKey  
              'PICKSLIP'  
            , 9  
            , @c_PickSlipNo   OUTPUT  
            , @b_Success      OUTPUT  
            , @n_Err          OUTPUT  
            , @c_Errmsg       OUTPUT  
            , 0  
            , @n_NoOfReqPSlip  
  
      IF @b_success <> 1  
      BEGIN  
         SET @n_Continue = 3  
         GOTO QUIT_SP  
      END  
  
      DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Orderkey  
      FROM #TMP_PCK  
      WHERE PickSlipNo = ''  
      ORDER BY Orderkey  
  
      OPEN CUR_PSLIP  
  
      FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
  
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo  
  
         BEGIN TRAN  
  
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)  
         VALUES (@c_PickHeaderKey, @c_OrderKey, @c_LoadKey, '0', '3', NULL)  
  
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SET @n_Continue = 3  
            GOTO QUIT_SP  
         END  
  
         UPDATE #TMP_PCK  
         SET PickSlipNo= @c_PickHeaderKey  
         WHERE Loadkey = @c_Loadkey  
         AND Orderkey  = @c_Orderkey  
  
         WHILE @@TRANCOUNT > 0  
         BEGIN  
            COMMIT TRAN  
         END  
  
         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)  
         FETCH NEXT FROM CUR_PSLIP INTO @c_Orderkey  
      END  
      CLOSE CUR_PSLIP  
      DEALLOCATE CUR_PSLIP  
   END  
  
   /*CS01 Start*/  
  
  
   DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PickSlipNo  
         ,OrderKey  
         ,Storerkey  
   FROM #TMP_PCK  
   ORDER BY PickSlipNo  
  
   OPEN CUR_PSNO  
  
   FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo  
                                ,@c_Orderkey  
                                ,@c_Storerkey  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_AutoScanIn = '0'  
      EXEC nspGetRight  
            @c_Facility   = @c_Facility  
         ,  @c_StorerKey  = @c_StorerKey  
         ,  @c_sku        = ''  
         ,  @c_ConfigKey  = 'AutoScanIn'  
         ,  @b_Success    = @b_Success    OUTPUT  
         ,  @c_authority  = @c_AutoScanIn OUTPUT  
         ,  @n_err        = @n_err        OUTPUT  
         ,  @c_errmsg     = @c_errmsg     OUTPUT  
  
      IF @b_Success = 0  
      BEGIN  
     SET @n_Continue = 3  
         GOTO QUIT_SP  
      END  
  
      BEGIN TRAN  
      IF @c_AutoScanIn = '1'  
      BEGIN  
         IF NOT EXISTS (SELECT 1  
                        FROM PICKINGINFO WITH (NOLOCK)  
                        WHERE PickSlipNo = @c_PickSlipNo  
                        )  
         BEGIN  
            INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)  
  
            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SET @n_Continue = 3  
               GOTO QUIT_SP  
            END  
         END  
      END  
  
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  
      FETCH NEXT FROM CUR_PSNO INTO @c_PickSlipNo  
                                   ,@c_Orderkey  
                                   ,@c_Storerkey  
   END  
   CLOSE CUR_PSNO  
   DEALLOCATE CUR_PSNO  
  
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
  
   INSERT INTO #TMP_PCK85  
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
   SELECT #TMP_PCK.PickSlipNo  
         ,Contact1 = ISNULL(RTRIM(ORDERS.c_contact1),'')  
         ,ODUDF03 = ISNULL(RTRIM(OD.Userdefine03),'')
         ,#TMP_PCK.Loadkey  
         ,#TMP_PCK.Orderkey  
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
   FROM #TMP_PCK  
   JOIN STORER     WITH (NOLOCK) ON (#TMP_PCK.Storerkey = STORER.Storerkey)  
   JOIN ORDERS     WITH (NOLOCK) ON (#TMP_PCK.Orderkey  = ORDERS.Orderkey)  
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.orderkey = ORDERS.Orderkey  
   JOIN PICKDETAIL WITH (NOLOCK) ON (OD.Orderkey    = PICKDETAIL.Orderkey  
                                     AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber
									 AND OD.SKU = PICKDETAIL.SKU)  
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)  
                                 AND(PICKDETAIL.Sku       = SKU.Sku)  
   LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey  
   --LEFT JOIN CODELKUP CL1 (NOLOCK) ON ORDERS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECLOGISTP'       --(CS01)
   LEFT JOIN CODELKUP  CL1 (NOLOCK) ON OI.PLATFORM = CL1.CODE AND OD.LOTTABLE02 = CL1.CODE2                  --(CS01)
   LEFT JOIN CODELKUP CL2 (NOLOCK) ON RTRIM(ORDERS.SHIPPERKEY) =  CL2.CODE AND CL2.LISTNAME = 'ECDLMODE'  AND CL2.STORERKEY = ORDERS.STORERKEY
   WHERE #TMP_PCK.PickSlipNo <> '' 
   --AND ORDERS.STATUS ='3'                  --CS01
   AND ORDERS.TYPE = 'ECOM' 
   GROUP BY #TMP_PCK.PickSlipNo  
         ,  ISNULL(RTRIM(ORDERS.c_contact1),'')  
         ,  ISNULL(RTRIM(OD.Userdefine03),'')
         ,  #TMP_PCK.Orderkey  
         ,  #TMP_PCK.Loadkey  
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
   ORDER BY #TMP_PCK.PickSlipNo  
           ,#TMP_PCK.Orderkey 
		   ,PICKDETAIL.Loc   
  
   
  SELECT * FROM #TMP_PCK85 AS tp  
  ORDER BY orderkey, loc
  
END -- procedure


GO