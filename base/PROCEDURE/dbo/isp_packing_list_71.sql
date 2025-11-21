SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_Packing_List_71                                     */
/* Creation Date: 12-Nov-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-11109 [TW]PEC Create new RCM report_Packing List         */
/*        :                                                             */
/* Called By:r_dw_packing_list_71                                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2020-02-17   WLChooi   1.1 WMS-12047 - Modify logic of SDescr (WL01) */
/* 2020-04-15   WLChooi   1.2 Fix Pickdetail Table Linkage (WL02)       */
/* 2020-03-25   WLChooi   1.3 WMS-12621 - Add QRCode, modify layout and */
/*                            logic (WL03)                              */
/* 2021-11-10   LZG       1.4 JSM-32522-Changed to PickDetail.Qty (ZG01)*/
/* 2022-02-10   SPChin    1.5 JSM-46792 - Bug Fixed                     */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_71]
            @c_Pickslipno     NVARCHAR(10)
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

         , @c_Orderkey        NVARCHAR(10)
         , @c_ExternOrderKey  NVARCHAR(50)
         , @c_Storerkey       NVARCHAR(15)

         , @c_RptLogo         NVARCHAR(255)
         , @c_ecomflag        NVARCHAR(50)
         , @n_MaxLineno       INT
         , @n_MaxId           INT
         , @n_MaxRec          INT
         , @n_CurrentRec      INT
         , @c_recgroup        INT
         , @c_QRCode          NVARCHAR(250)   --WL03

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_Errmsg    = ''
   SET @c_RptLogo   = ''

   SET @n_MaxLineno = 10
   SET @n_MaxId     = 1
   SET @n_MaxRec    = 1
   SET @n_CurrentRec= 1
   SET @c_recgroup  = 1

   CREATE TABLE #TMP_PACK_71
      ( rowid             INT NOT NULL identity(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NOT NULL
      , OrdDate           DATETIME
      , PickSlipNo        NVARCHAR(10)   NOT NULL
      , OIPlatform        NVARCHAR(40)
      , EditDate          DATETIME
      , Contact1          NVARCHAR(45)   NULL
      , SKU               NVARCHAR(30)   NULL
      , RetailSKU         NVARCHAR(20)   NULL
      , Notes             NVARCHAR(800)  NULL
      , Qty               INT
      , CUDF01            NVARCHAR(255)  NULL
      , PHBarcode         NVARCHAR(100)
      , OSBarcode         NVARCHAR(100)
      , EcomOrdIDBarcode  NVARCHAR(100)
      , RPTLOGO           NVARCHAR(255) NULL
      , EcomOrdID         NVARCHAR(45) NULL
      , PLOC              NVARCHAR(10) NULL
      , SDESCR            NVARCHAR(150) NULL
      , Notes2            NVARCHAR(800)  NULL
      , ReferenceId       NVARCHAR(20) NULL
      , SSIZE             NVARCHAR(10) NULL
      , QRCode            NVARCHAR(250) NULL    --WL03
      )

     IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         SELECT TOP 1 @c_ecomflag = LTRIM(RTRIM(ISNULL(ORD.TYPE,'')))
         FROM ORDERS ORD (NOLOCK)
         JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = ORD.ORDERKEY
         WHERE PH.Pickslipno = @c_Pickslipno

         IF (@c_ecomflag <> 'ECOM')
         GOTO QUIT_SP
      END

      IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         SELECT TOP 1 @c_RptLogo = ISNULL(CL2.Long,'')
                    , @c_QRCode  = ISNULL(CL2.UDF01,'')   --WL03
         FROM ORDERS ORD (NOLOCK)
         JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = ORD.ORDERKEY
         JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME='RPTLogo' AND CL2.Storerkey=ORD.storerkey AND CL2.Code=ORD.OrderGroup
         WHERE PH.Pickslipno = @c_Pickslipno

      END

      IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         INSERT INTO #TMP_PACK_71
                    (  Orderkey
                     , OrdDate
                     , PickSlipNo
                     , OIPlatform
                     , EditDate
                     , Contact1
                     , SKU
                     , RetailSKU
                     , Notes
                     , Qty
                     , CUDF01
                     , PHBarcode
                     , OSBarcode
                     , EcomOrdIDBarcode
                     , rptlogo
                     , EcomOrdID
                     , PLOC
                     , SDESCR
                     , notes2
                     , ReferenceId
                     , SSIZE
                     , QRCode    --WL03
                    )
         SELECT  OS.ORDERKEY
               , OS.OrderDate
               , PH.PICKSLIPNO
               , ISNULL(CL2.[UDF01],'')
               , OS.EditDate
               , OS.C_CONTACT1
               , (SKU.STYLE + SKU.COLOR)
              -- , SKU.RetailSKU
               , OD.Userdefine01 --OD.Userdefine03   --WL03
               , ISNULL(CL3.NOTES,'')
               , SUM(PID.Qty)               --JSM-46792, ZG01
               , ISNULL(CL1.UDF01,'')
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(PH.PICKSLIPNO)))
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OS.ORDERKEY)))
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OI.Ecomorderid)))
               , ISNULL(@c_RptLogo,'')
               , OI.Ecomorderid
               , PID.loc
               --, SKU.descr
               --, (ISNULL(OD.Userdefine01,'') + ISNULL(OD.Userdefine02,'')) --WL01
               , ISNULL(OD.Notes,'') --WL01
               , ISNULL(CL4.NOTES,'')
               , ISNULL(OI.ReferenceId,'')
               , SKU.Size
               , ISNULL(@c_QRCode,'') AS QRCode   --WL03
         FROM ORDERS OS (NOLOCK)
         LEFT JOIN ORDERINFO OI (NOLOCK) ON OS.ORDERKEY = OI.ORDERKEY
         JOIN ORDERDETAIL OD(NOLOCK) ON OD.ORDERKEY = OS.ORDERKEY
         JOIN SKU (NOLOCK) ON OD.SKU = SKU.SKU AND OD.STORERKEY = SKU.STORERKEY
         JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY =OS.ORDERKEY AND PH.STORERKEY = OS.STORERKEY
         --JOIN PACKDETAIL PD (NOLOCK) ON PD.PICKSLIPNO = PH.PICKSLIPNO AND PD.SKU = OD.SKU  --JSM-46792
         JOIN PICKDETAIL PID (NOLOCK) ON PID.Orderkey = OD.Orderkey AND PID.SKU = OD.SKU AND PID.OrderLineNumber = OD.OrderLineNumber   --WL02
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON OS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECDLMODE' and CL1.Code = OS.Shipperkey and CL1.Code2 = ''   --WL03
         LEFT JOIN CODELKUP CL2 (NOLOCK) ON OS.STORERKEY = CL2.STORERKEY AND CL2.LISTNAME ='PLATFORM' and CL2.Code = OI.Platform
         LEFT JOIN CODELKUP CL3 (NOLOCK) ON OS.STORERKEY = CL3.STORERKEY AND CL3.LISTNAME ='REPORTCFG' and CL3.Code = '01'
         LEFT JOIN CODELKUP CL4 (NOLOCK) ON OS.STORERKEY = CL4.STORERKEY AND CL4.LISTNAME ='REPORTCFG' and CL4.Code = '02'
         WHERE PH.PickSlipNo = @c_Pickslipno AND OS.[TYPE] = 'ECOM'
         GROUP BY OS.ORDERKEY
               , OS.OrderDate
               , PH.PICKSLIPNO
               , ISNULL(CL2.[UDF01],'')
               , OS.EditDate
               , OS.C_CONTACT1
              -- , PD.SKU
               , (SKU.STYLE + SKU.COLOR)
              -- , SKU.RetailSKU
               , OD.Userdefine01 --OD.Userdefine03   --WL03
               , ISNULL(CL3.NOTES,'')
               --, PID.Qty                           --JSM-46792, ZG01
               , ISNULL(CL1.UDF01,'')
               , OI.Ecomorderid
               , PID.Loc
             --, SKU.descr
               --, (ISNULL(OD.Userdefine01,'') + ISNULL(OD.Userdefine02,''))  --WL01
               , ISNULL(OD.Notes,'')
               , ISNULL(CL4.NOTES,'')
               , ISNULL(OI.ReferenceId,'')
               , SKU.Size
         ORDER BY PH.PICKSLIPNO
                 ,OS.ORDERKEY
      END



QUIT_SP:
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

  SELECT  Orderkey
        , OrdDate
        , PickSlipNo
        , OIPlatform
        , EditDate
        , Contact1
        , SKU
        , RetailSKU
        , Notes
        , Qty
        , CUDF01
        , PHBarcode
        , OSBarcode
        , EcomOrdIDBarcode
        , RptLogo
        , EcomOrdID
        , PLOC
        , SDESCR
        , Notes2
        , ReferenceId
        , SSIZE
        , QRCode   --WL01
  FROM #TMP_PACK_71
  ORDER BY ROWID
         , Orderkey

  IF OBJECT_ID('tempdb..##TMP_PACK_71') IS NOT NULL
   DROP TABLE #TMP_PACK_71


END -- procedure


GO