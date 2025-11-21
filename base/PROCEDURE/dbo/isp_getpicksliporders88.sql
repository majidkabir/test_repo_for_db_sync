SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipOrders88                                 */
/* Creation Date: 25-Mar-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:WMS-8099- [TW-VFEC]EC PickSlip RCMReport_CR                  */
/*        :                                                             */
/* Called By:r_dw_print_pickorder88                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2019-08-28   WLChooi   1.1 WMS-10360 - Add new parameter (WL01)      */
/* 2020-07-17   WLChooi   1.2 WMS-14316-Modify logic to get Notes (WL02)*/
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders88]
            @c_Loadkey      NVARCHAR(10),
            @c_OrderkeyFrom NVARCHAR(10) = '',     --WL01
            @c_OrderkeyTo   NVARCHAR(10) = ''      --WL01
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

         , @c_PSNo            NVARCHAR(20)
         , @c_loc             NVARCHAR(50)
         , @c_sku             NVARCHAR(50)

         , @n_rowid           INT

         , @c_MinOrderkey     NVARCHAR(10)
         , @c_MaxOrderkey     NVARCHAR(10)

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

   IF @c_OrderkeyFrom = NULL SET @c_OrderkeyFrom = '' --WL01
   IF @c_OrderkeyTo   = NULL SET @c_OrderkeyTo   = '' --WL01

   --WL01 Start
   SELECT @c_MinOrderkey = MIN(Orderkey)
        , @c_MaxOrderkey = MAX(Orderkey)
   FROM LOADPLANDETAIL (NOLOCK)
   WHERE Loadkey = @c_Loadkey
   --WL01 End

   CREATE TABLE #TMP_PCK
      ( Loadkey      NVARCHAR(10)   NOT NULL
      , Orderkey     NVARCHAR(10)   NOT NULL
      , PickSlipNo   NVARCHAR(10)   NOT NULL
      , Storerkey    NVARCHAR(15)   NOT NULL
      , logo         NVARCHAR(255)  NULL
		, RNotes       NVARCHAR(255)  NULL
      )

   CREATE TABLE #TMP_PCK88
      ( rowid           INT NOT NULL identity(1,1) PRIMARY KEY
      , PickSlipNo      NVARCHAR(10)   NOT NULL
      , Contact1        NVARCHAR(45)   NULL
      , SYCOLORSZ       NVARCHAR(80)   NULL
      , Loadkey         NVARCHAR(10)   NOT NULL
      , Orderkey        NVARCHAR(10)   NOT NULL
      , OrdDate         DATETIME
      , EditDate        DATETIME
      , ExternOrderkey  NVARCHAR(50)   NULL
      , Notes           NVARCHAR(255)  NULL
      , Loc             NVARCHAR(20)   NULL
      , Storerkey       NVARCHAR(15)   NOT NULL
      , SKU             NVARCHAR(20)   NULL
      , PFUDF01         NVARCHAR(255)  NULL
      , EMUDF01         NVARCHAR(255)  NULL
      , Qty             INT
      , JCLONG          NVARCHAR(255)  NULL
      , Pageno          INT
		, RptNotes        NVARCHAR(255)
      , RowNo           NVARCHAR(40)
      )

   CREATE TABLE #TMP_PCK88_Final
      ( rowid           INT NOT NULL identity(1,1) PRIMARY KEY
      , PickSlipNo      NVARCHAR(10)   NOT NULL
      , Contact1        NVARCHAR(45)   NULL
      , SYCOLORSZ       NVARCHAR(80)   NULL
      , Loadkey         NVARCHAR(10)   NOT NULL
      , Orderkey        NVARCHAR(10)   NOT NULL
      , OrdDate         DATETIME
      , EditDate        DATETIME
      , ExternOrderkey  NVARCHAR(50)   NULL
      , Notes           NVARCHAR(255)  NULL
      , Loc             NVARCHAR(20)   NULL
      , Storerkey       NVARCHAR(15)   NOT NULL
      , SKU             NVARCHAR(20)   NULL
      , PFUDF01         NVARCHAR(255)  NULL
      , EMUDF01         NVARCHAR(255)  NULL
      , Qty             INT
      , JCLONG          NVARCHAR(255)  NULL
      , Pageno          INT
		, RptNotes        NVARCHAR(255)
      , RowNo           NVARCHAR(40)
      )

   CREATE TABLE #UniquePSNO
      (  rowid           INT NOT NULL identity(1,1) PRIMARY KEY
       , PickslipNo      NVARCHAR(10)   NOT NULL
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
      , logo
		, RNotes
      )

   SELECT DISTINCT
          LOADPLANDETAIL.Loadkey
         ,LOADPLANDETAIL.Orderkey
         ,ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
         ,ORDERS.Storerkey
         ,''
			,''
   FROM LOADPLANDETAIL  WITH (NOLOCK)
   JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   LEFT JOIN PICKHEADER WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey  = PICKHEADER.ExternOrderkey)
                                      AND(LOADPLANDETAIL.Orderkey = PICKHEADER.Orderkey)
   WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
   AND LOADPLANDETAIL.OrderKey >= CASE WHEN @c_OrderkeyFrom = '' THEN @c_MinOrderkey ELSE @c_OrderkeyFrom END   --WL01
   AND LOADPLANDETAIL.OrderKey <= CASE WHEN @c_OrderkeyTo = '' THEN @c_MaxOrderkey ELSE @c_OrderkeyTo END       --WL01
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

      SET @c_logo = ''
      SET @c_logo = (select top 1 OH.ordergroup from orders oh with (nolock) WHERE ORDERKEY = @c_Orderkey)


      SET @c_JCLONG = ''
      SELECT @c_JCLONG = C3.Long
      FROM CODELKUP C3 WITH (NOLOCK)
      WHERE C3.LISTNAME='RPTLogo' AND C3.Storerkey=@c_StorerKey
      AND C3.CODE = @c_Logo

		SET @c_RNotes = ''

      --WL02 START
		--SELECT @c_RNotes = ISNULL(C4.Notes,'')
		--FROM CODELKUP C4 WITH (NOLOCK)
      --WHERE C4.LISTNAME='REPORTCFG'   AND C4.Storerkey=@c_StorerKey
      --AND C4.Code =  @c_Logo AND C4.long='r_dw_print_pickorder88'

      SELECT @c_RNotes = ISNULL(CL.Notes,'')
      FROM ORDERS OH (NOLOCK) 
      LEFT JOIN ORDERINFO OI (NOLOCK) ON OI.Orderkey = OH.Orderkey
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Storerkey = OH.Storerkey
                                    AND CL.Code = ISNULL(OI.[Platform],'') AND CL.Short = OH.OrderGroup
                                    AND CL.Long = 'r_dw_print_pickorder88'
      WHERE OH.Orderkey = @c_Orderkey
      --WL02 END

      UPDATE #TMP_PCK
      SET logo = @c_JCLONG
		   ,RNotes = @c_RNotes
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

   INSERT INTO #TMP_PCK88
              ( PickSlipNo
              , Contact1
              , SYCOLORSZ
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
				  , RptNotes
              , RowNo
              )
   SELECT #TMP_PCK.PickSlipNo
         ,Contact1 = ISNULL(RTRIM(ORDERS.c_contact1),'')
         ,SYCOLORSZ = PICKDETAIL.sku--ISNULL(SKU.Style,'') + '-' + ISNULL(SKU.color,'') + '-' + ISNULL(SKU.Size,'')
         ,#TMP_PCK.Loadkey
         ,#TMP_PCK.Orderkey
         ,OrdDate   = ORDERS.OrderDate
         ,EditDate   = ORDERS.EditDate
         ,ExternOrderkey = ISNULL(RTRIM(OI.EcomOrderId),'')
         ,Notes   = ISNULL(RTRIM(OD.Notes),'')
         ,PICKDETAIL.Loc
         ,PICKDETAIL.Storerkey
         ,SKU = SKU.Altsku--PICKDETAIL.sku
         ,PFUDF01 = ISNULL(C1.UDF01,'')
         ,EMUDF01 = ISNULL(C2.UDF01,'')
         ,Qty = ISNULL(SUM(PICKDETAIL.Qty),0)
         ,JCLONG = ISNULL(#TMP_PCK.logo,'')
         ,pageno = (Row_number() OVER (PARTITION BY #TMP_PCK.PickSlipNo ORDER BY #TMP_PCK.PickSlipNo,#TMP_PCK.Orderkey,PICKDETAIL.sku asc))/@n_MaxLine
			,RptNotes = ISNULL(#TMP_PCK.RNotes,'')
         ,ROW_NUMBER() OVER(Partition by #TMP_PCK.PickSlipNo ORDER BY PICKDETAIL.Loc,PICKDETAIL.sku) AS RowNo
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
   --LEFT JOIN CODELKUP C3 WITH (NOLOCK) ON C3.LISTNAME='REPORTCFG'   AND C3.Storerkey=ORDERS.StorerKey
   --                                   AND C3.Code =  'CustCol01' AND C3.long='r_dw_print_pickorder82'
   WHERE #TMP_PCK.PickSlipNo <> ''
   GROUP BY #TMP_PCK.PickSlipNo
         ,  ISNULL(RTRIM(ORDERS.c_contact1),'')
         ,  SKU.Altsku--ISNULL(SKU.Style,'') + '-' + ISNULL(SKU.color,'') + '-' + ISNULL(SKU.Size,'')
         ,  #TMP_PCK.Orderkey
         ,  #TMP_PCK.Loadkey
         ,  ORDERS.OrderDate
         ,  ORDERS.EditDate
         , ISNULL(RTRIM(OI.EcomOrderId),'')
         ,  ISNULL(RTRIM(OD.Notes),'')
         ,  PICKDETAIL.Loc
         ,  PICKDETAIL.Storerkey
         ,  PICKDETAIL.sku
         ,  ISNULL(C1.UDF01,'')
         ,  ISNULL(C2.UDF01,'')
         ,  ISNULL(#TMP_PCK.logo,'')
			,  ISNULL(#TMP_PCK.RNotes,'')


    /*CS01 Start*/
   ORDER BY #TMP_PCK.PickSlipNo
           ,PICKDETAIL.sku

  SELECT @c_MaxPSlipno = MAX(pickslipno)
         ,@n_CntRec = COUNT(1)
         ,@n_LastPage = MAX(tp.Pageno)
  FROM #TMP_PCK88 AS tp
  GROUP BY tp.PickSlipNo

--select * from #TMP_PCK88 order by loc

  IF @n_CntRec > @n_MaxLine
  BEGIN
   SET @n_ReqLine = @n_MaxLine - (@n_CntRec - @n_MaxLine) - 1
  END
  ELSE
  BEGIN
   SET @n_ReqLine = @n_MaxLine - @n_CntRec - 1
  END

  /*Sorting by LOC first then group by orderkey (WL01) */
  --Get unique psno order by loc,sku
  DECLARE CUR_sort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT Pickslipno, LOC, SKU from #TMP_PCK88 WHERE ROWNO = 1 ORDER BY LOC,PICKSLIPNO,SKU DESC
  OPEN CUR_sort

  FETCH NEXT FROM CUR_sort INTO @c_psno, @c_loc, @c_sku
  WHILE @@FETCH_STATUS <> -1     
  BEGIN

    INSERT INTO #UniquePSNO (PickslipNo)
    SELECT @c_PSNo

  FETCH NEXT FROM CUR_sort INTO @c_psno, @c_loc, @c_sku                    
  END
  CLOSE CUR_sort
  DEALLOCATE CUR_sort

 --select * from #UniquePSNO order by rowid

  --Group same orderkey together
  DECLARE CUR_PSNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT DISTINCT ROWID,PickslipNo from #UniquePSNO order by rowid
  OPEN CUR_PSNO

  FETCH NEXT FROM CUR_PSNO INTO @n_rowid,@c_psno 
  WHILE @@FETCH_STATUS <> -1     
  BEGIN

     INSERT INTO #TMP_PCK88_Final (PickSlipNo, Contact1, SYCOLORSZ, Loadkey, Orderkey, OrdDate, EditDate       
      , ExternOrderkey, Notes, Loc, Storerkey, SKU, PFUDF01, EMUDF01 , Qty, JCLONG, Pageno, RptNotes, RowNo )
     SELECT PickSlipNo, Contact1, SYCOLORSZ, Loadkey, Orderkey, OrdDate, EditDate       
      , ExternOrderkey, Notes, Loc, Storerkey, SKU, PFUDF01, EMUDF01 , Qty, JCLONG, Pageno, RptNotes, RowNo 
      FROM #TMP_PCK88
     WHERE PickSlipNo NOT IN (SELECT DISTINCT PickSlipNo from #TMP_PCK88_Final) and PickSlipNo = @c_psno
     ORDER BY LOC,SKU

  FETCH NEXT FROM CUR_PSNO INTO @n_rowid,@c_psno                   
  END
  CLOSE CUR_PSNO
  DEALLOCATE CUR_PSNO

  --SELECT @c_MaxPSlipno '@c_MaxPSlipno',@n_CntRec '@n_CntRec',@n_LastPage '@n_LastPage',@n_ReqLine '@n_ReqLine'

/*  WHILE @n_ReqLine >= 1
  BEGIN

   --SELECT @n_ReqLine '@n_ReqLine'
   INSERT INTO #TMP_PCK88
              ( PickSlipNo
              , Contact1
              , SYCOLORSZ
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
				  , RptNotes
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
					, ''
      FROM #TMP_PCK88 AS tp
      WHERE tp.PickSlipNo= @c_MaxPSlipno
      AND tp.Pageno = @n_LastPage


      SET @n_ReqLine  = @n_ReqLine - 1

  END*/

  SELECT * FROM #TMP_PCK88_FINAL AS tp order by rowid

END -- procedure

GO