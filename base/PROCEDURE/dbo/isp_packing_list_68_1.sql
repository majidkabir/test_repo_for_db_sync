SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_list_68_1                                   */
/* Creation Date: 25-SEP-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:WMS-10695 - Copied from isp_GetPickSlipOrders66_ecom         */
/*        :                                                             */
/* Called By:r_dw_print_packlist_10_1                                   */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_list_68_1]
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
      --   , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @c_AutoScanIn      NVARCHAR(10)
         , @c_Facility        NVARCHAR(5)      --(CS01)
         , @c_Logo            NVARCHAR(50)     --(WL01)
         , @n_MaxLine         INT
         , @n_CntRec          INT
         , @c_MaxPSlipno      NVARCHAR(10)
         , @n_LastPage        INT
         , @n_ReqLine         INT
         , @c_JCLONG          NVARCHAR(255)  --INC0072296

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''
   SET @c_Logo     = '' --(WL01)
   SET @n_MaxLine  = 9
   SET @n_CntRec   = 1
   SET @n_LastPage = 0
   SET @n_ReqLine  = 1

   CREATE TABLE #TMP_PCK
      ( Loadkey      NVARCHAR(10)   NOT NULL
      , Orderkey     NVARCHAR(10)   NOT NULL
      , PickSlipNo   NVARCHAR(10)   NOT NULL
      , Storerkey    NVARCHAR(15)   NOT NULL
      , logo         NVARCHAR(255)  NULL    --INC0072296
      )

   CREATE TABLE #TMP_PCK100
      ( PickSlipNo      NVARCHAR(10)   NOT NULL
      , Contact1        NVARCHAR(45)   NULL
      , ODUDF03         NVARCHAR(30)   NULL
      , Loadkey         NVARCHAR(10)   NOT NULL
      , Orderkey        NVARCHAR(10)   NOT NULL
      , OrdDate         DATETIME
      , EditDate        DATETIME
      , ExternOrderkey  NVARCHAR(50)   NULL  --tlting_ext
      , Notes           NVARCHAR(255)  NULL
      , Loc             NVARCHAR(20)   NULL
      , Storerkey       NVARCHAR(15)   NOT NULL
      , SKU             NVARCHAR(20)   NULL
      , PFUDF01         NVARCHAR(255)  NULL
      , EMUDF01         NVARCHAR(255)  NULL
      , Qty             INT
      , JCLONG          NVARCHAR(255)  NULL
      , Pageno          INT
      , RptNotes        NVARCHAR(255)                  --CS03
      )

      --SET @c_Facility = ''
      --SELECT @c_Facility = Facility
      --FROM LOADPLAN WITH (NOLOCK)
      --WHERE Loadkey = @c_Loadkey

   INSERT INTO #TMP_PCK
      ( Loadkey
      , Orderkey
      , PickSlipNo
      , Storerkey
      , logo
      )

   SELECT DISTINCT
          LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,ORDERS.Storerkey
         ,''
   FROM LOADPLANDETAIL  WITH (NOLOCK)
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)
                 --                     AND(LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)
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

   --SET @n_NoOfReqPSlip  = 0

   --SELECT @n_NoOfReqPSlip = COUNT(1)
   --FROM #TMP_PCK
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
   --   FROM #TMP_PCK
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

   --      UPDATE #TMP_PCK
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
      --SET @c_AutoScanIn = '0'
      --EXEC nspGetRight
      --      @c_Facility   = @c_Facility
      --   ,  @c_StorerKey  = @c_StorerKey
      --   ,  @c_sku        = ''
      --   ,  @c_ConfigKey  = 'AutoScanIn'
      --   ,  @b_Success    = @b_Success    OUTPUT
      --   ,  @c_authority  = @c_AutoScanIn OUTPUT
      --   ,  @n_err        = @n_err        OUTPUT
      --   ,  @c_errmsg     = @c_errmsg     OUTPUT

      --IF @b_Success = 0
      --BEGIN
      --   SET @n_Continue = 3
      --   GOTO QUIT_SP
      --END

      --BEGIN TRAN
      --IF @c_AutoScanIn = '1'
      --BEGIN
      --   IF NOT EXISTS (SELECT 1
      --                  FROM PICKINGINFO WITH (NOLOCK)
      --                  WHERE PickSlipNo = @c_PickSlipNo
      --                  )
      --   BEGIN
      --      INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
      --      VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)

      --      SET @n_err = @@ERROR
      --      IF @n_err <> 0
      --      BEGIN
      --         SET @n_Continue = 3
      --         GOTO QUIT_SP
      --      END
      --   END
      --END

      /*WL01 Start*/
      SET @c_logo = ''
      SET @c_logo = (select top 1 itemclass from orderdetail with (nolock) JOIN SKU with (nolock) ON (ORDERDETAIL.STORERKEY = SKU.STORERKEY) AND
                     ORDERDETAIL.SKU = SKU.SKU WHERE ORDERKEY = @c_Orderkey)

      --INC0072296 start
      SET @c_JCLONG = ''
      SELECT @c_JCLONG = C3.Long
      FROM CODELKUP C3 WITH (NOLOCK)
      WHERE C3.LISTNAME='JETCompany' AND C3.Storerkey=@c_StorerKey --(WL01)
      AND C3.CODE = @c_Logo --(WL01)

      UPDATE #TMP_PCK
      SET logo = @c_JCLONG
      WHERE PickSlipNo = @c_PickSlipNo
      AND Orderkey = @c_Orderkey
      AND Storerkey = @c_Storerkey
      --INC0072296 end
      /*WL01 End*/

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

   INSERT INTO #TMP_PCK100
              ( PickSlipNo
              , Contact1
              , ODUDF03
              , Loadkey
              , Orderkey
              , OrdDate
              , EditDate
              , ExternOrderkey
              , Notes
              , Loc
              , Storerkey
              , SKU
              , PFUDF01
              , EMUDF01
              , Qty
              , JCLONG
              , Pageno
              ,RptNotes                   --CS03
              )
   SELECT #TMP_PCK.PickSlipNo
         ,Contact1 = ISNULL(RTRIM(ORDERS.c_contact1),'')
         ,ODUDF03 = ISNULL(OD.userdefine03,'')
         ,#TMP_PCK.Loadkey
         ,#TMP_PCK.Orderkey
         ,OrdDate   = ORDERS.OrderDate
         ,EditDate   = ORDERS.EditDate
         --,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')               --CS02
         ,ExternOrderkey = ISNULL(RTRIM(OI.EcomOrderId),'')                   --CS02
         ,Notes   = ISNULL(RTRIM(OD.Notes),'')
         ,PICKDETAIL.Loc
         ,PICKDETAIL.Storerkey
         ,SKU = PICKDETAIL.sku
         ,PFUDF01 = ISNULL(C1.UDF01,'')
         ,EMUDF01 = ISNULL(C2.UDF01,'')
         ,Qty = ISNULL(SUM(PICKDETAIL.Qty),0)
         --,JCLONG = ISNULL(C3.LONG,'')       --(WL01)
         ,JCLONG = ISNULL(#TMP_PCK.logo,'')   --INC0072296
         ,pageno = (Row_number() OVER (PARTITION BY #TMP_PCK.PickSlipNo ORDER BY #TMP_PCK.PickSlipNo,#TMP_PCK.Orderkey,PICKDETAIL.sku asc))/@n_MaxLine
         ,RptNotes = ISNULL(C1.Notes,'')                --CS03
   FROM #TMP_PCK
   JOIN STORER     WITH (NOLOCK) ON (#TMP_PCK.Storerkey = STORER.Storerkey)
   JOIN ORDERS     WITH (NOLOCK) ON (#TMP_PCK.Orderkey  = ORDERS.Orderkey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.orderkey = ORDERS.Orderkey
   JOIN PICKDETAIL WITH (NOLOCK) ON (OD.Orderkey    = PICKDETAIL.Orderkey
                                     AND PICKDETAIL.OrderLineNumber = OD.OrderLineNumber)
   JOIN SKU        WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)
                                 AND(PICKDETAIL.Sku       = SKU.Sku)
   LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey = ORDERS.OrderKey
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'PLATFORM' AND C1.Storerkey=ORDERS.StorerKey
                                      AND C1.Code =  OI.Platform
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON C2.LISTNAME='ECDLMODE'   AND C2.Storerkey=ORDERS.StorerKey
                                      AND C2.Code =  ORDERS.Shipperkey
   --LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.LISTNAME='JETCompany'   AND C3.Storerkey=ORDERS.StorerKey --(WL01)
   --                          AND C3.CODE = @c_Logo --(WL01)
   WHERE #TMP_PCK.PickSlipNo <> ''
   GROUP BY #TMP_PCK.PickSlipNo
         ,  ISNULL(RTRIM(ORDERS.c_contact1),'')
         ,  ISNULL(OD.userdefine03,'')
         ,  #TMP_PCK.Orderkey
         ,  #TMP_PCK.Loadkey
         ,  ORDERS.OrderDate
         ,  ORDERS.EditDate
         --,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')         --CS02
         , ISNULL(RTRIM(OI.EcomOrderId),'')                   --CS02
         ,  ISNULL(RTRIM(OD.Notes),'')
         ,  PICKDETAIL.Loc
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.sku
         ,  ISNULL(C1.UDF01,'')
         ,  ISNULL(C2.UDF01,'')
         ,  ISNULL(#TMP_PCK.logo,'')    --INC0072296
         --,  ISNULL(C3.LONG,'') --(WL01)
         ,ISNULL(C1.Notes,'')             --CS03

    /*CS01 Start*/
   ORDER BY #TMP_PCK.PickSlipNo
           ,PICKDETAIL.sku

  SELECT @c_MaxPSlipno = MAX(pickslipno)
         ,@n_CntRec = COUNT(1)
         ,@n_LastPage = MAX(tp.Pageno)
  FROM #TMP_PCK100 AS tp
  GROUP BY tp.PickSlipNo


  IF @n_CntRec > @n_MaxLine
  BEGIN
   SET @n_ReqLine = @n_MaxLine - (@n_CntRec - @n_MaxLine) - 1
  END
  ELSE
  BEGIN
   SET @n_ReqLine = @n_MaxLine - @n_CntRec - 1
  END

  --SELECT @c_MaxPSlipno '@c_MaxPSlipno',@n_CntRec '@n_CntRec',@n_LastPage '@n_LastPage',@n_ReqLine '@n_ReqLine'

  WHILE @n_ReqLine >= 1
  BEGIN

   --SELECT @n_ReqLine '@n_ReqLine'
   INSERT INTO #TMP_PCK100
              ( PickSlipNo
              , Contact1
              , ODUDF03
              , Loadkey
              , Orderkey
              , OrdDate
              , EditDate
              , ExternOrderkey
              , Notes
              , Loc
              , Storerkey
              , SKU
              , PFUDF01
              , EMUDF01
              , Qty
              , JCLONG
              , Pageno
              ,RptNotes              --CS03
              )
      SELECT  TOP 1   @c_MaxPSlipno
               , ''
               , ''
               , Loadkey
               , Orderkey
               , ''
               , ''
               , ''
               , ''
               , ''
               , Storerkey
               , ''
               , ''
               , ''
               , 0
               , ''
               , @n_LastPage
               ,RptNotes          --CS03
      FROM #TMP_PCK100 AS tp
      WHERE tp.PickSlipNo= @c_MaxPSlipno
      AND tp.Pageno = @n_LastPage


      SET @n_ReqLine  = @n_ReqLine - 1

  END

  SELECT * FROM #TMP_PCK100 AS tp
  ORDER BY pickslipno,
           CASE WHEN sku = '' THEN 2 ELSE 1 END,tp.Pageno

END -- procedure

GO