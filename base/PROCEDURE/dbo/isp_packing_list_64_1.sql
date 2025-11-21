SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_64_1                                   */
/* Creation Date: 12-Apr-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:WMS-8653- [TW] LVS B2C Exceed PackList RCMreport             */
/*        :                                                             */
/* Called By:r_dw_packing_list_64_1    (ECOM)                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 10-Dec-2019  Leong     1.1 INC0803685 - Bug fix.                     */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_64_1]
   @c_Pickslipno NVARCHAR(10)
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

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1
   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @c_Errmsg    = ''
   SET @c_RptLogo   = ''

   SET @n_MaxLineno = 9 -- INC0803685
   SET @n_MaxId     = 1
   SET @n_MaxRec    = 1
   SET @n_CurrentRec= 1
   SET @c_recgroup  = 1

   CREATE TABLE #TMP_PACK_58
      ( rowid             INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NOT NULL
      , ExternOrderkey    NVARCHAR(50)   NULL
      , PickSlipNo        NVARCHAR(10)   NOT NULL
      , OIPlatform        NVARCHAR(40)   NULL
      , DelDate           DATETIME       NULL
      , Contact1          NVARCHAR(45)   NULL
      , SKU               NVARCHAR(20)   NULL
      , ManufacturerSKU   NVARCHAR(20)   NULL
      , Notes             NVARCHAR(255)  NULL
      , Qty               INT            NULL
      , CUDF02            NVARCHAR(255)  NULL
      , PHBarcode         NVARCHAR(100)  NULL
      , OSBarcode         NVARCHAR(100)  NULL
      , EXTORDBarcode     NVARCHAR(100)  NULL
    --, RPTLOGO           NVARCHAR(255)       -- INC0803685
      )

      CREATE TABLE #TMP_PACK_58_1
      ( rowid             INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NOT NULL
      , ExternOrderkey    NVARCHAR(50)   NULL
      , PickSlipNo        NVARCHAR(10)   NOT NULL
      , OIPlatform        NVARCHAR(40)   NULL
      , DelDate           DATETIME       NULL
      , Contact1          NVARCHAR(45)   NULL
      , SKU               NVARCHAR(20)   NULL
      , ManufacturerSKU   NVARCHAR(20)   NULL
      , Notes             NVARCHAR(255)  NULL
      , Qty               INT            NULL
      , CUDF02            NVARCHAR(255)  NULL
      , PHBarcode         NVARCHAR(100)  NULL
      , OSBarcode         NVARCHAR(100)  NULL
      , EXTORDBarcode     NVARCHAR(100)  NULL
      , recgroup          INT            NULL
      , ShowNo            NVARCHAR(1)    NULL
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
         SELECT @c_RptLogo = CL2.Long
         FROM CODELKUP CL2 WITH (NOLOCK)
         WHERE CL2.LISTNAME='RPTLogo' AND CL2.Storerkey=(SELECT TOP 1 STORERKEY FROM PACKHEADER (NOLOCK) WHERE PICKSLIPNO = @c_Pickslipno )
         AND CL2.CODE = 'LVSPACK'
      END

      IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         INSERT INTO #TMP_PACK_58
                    (  Orderkey
                     , ExternOrderkey
                     , PickSlipNo
                     , OIPlatform
                     , DelDate
                     , Contact1
                     , SKU
                     , ManufacturerSKU
                     , Notes
                     , Qty
                     , CUDF02
                     , PHBarcode
                     , OSBarcode
                     , EXTORDBarcode
                    )
         SELECT  OS.ORDERKEY
               , OS.EXTERNORDERKEY
               , PH.PICKSLIPNO
               , ISNULL(OI.[PLATFORM],'')
               , OS.DELIVERYDATE
               , OS.C_CONTACT1
               , PD.SKU
               , SKU.MANUFACTURERSKU
               , ISNULL(OD.NOTES,'')
               , PD.Qty
               , ISNULL(CL1.UDF02,'')
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(PH.PICKSLIPNO)))
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OS.ORDERKEY)))
               , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OS.EXTERNORDERKEY)))
         FROM ORDERS OS (NOLOCK)
         LEFT JOIN ORDERINFO OI (NOLOCK) ON OS.ORDERKEY = OI.ORDERKEY
         JOIN ORDERDETAIL OD(NOLOCK) ON OD.ORDERKEY = OS.ORDERKEY
         JOIN SKU (NOLOCK) ON OD.SKU = SKU.SKU AND OD.STORERKEY = SKU.STORERKEY
         JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY =OS.ORDERKEY AND PH.STORERKEY = OS.STORERKEY
         JOIN PACKDETAIL PD (NOLOCk) ON PD.PICKSLIPNO = PH.PICKSLIPNO AND PD.SKU = OD.SKU
         LEFT JOIN CODELKUP CL1 (NOLOCK) ON OS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECDLMODE' and CL1.Code = OS.Shipperkey
         WHERE PH.PickSlipNo = @c_Pickslipno AND OS.[TYPE] = 'ECOM'
         GROUP BY OS.ORDERKEY
               , OS.EXTERNORDERKEY
               , PH.PICKSLIPNO
               , ISNULL(OI.[PLATFORM],'')
               , OS.DELIVERYDATE
               , OS.C_CONTACT1
               , PD.SKU
               , SKU.MANUFACTURERSKU
               , ISNULL(OD.NOTES,'')
               , PD.Qty
               , ISNULL(CL1.UDF02,'')
         ORDER BY PH.PICKSLIPNO
                 ,OS.ORDERKEY
      END

      IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
        DECLARE CUR_psno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT OrderKey, ExternOrderkey
        FROM #TMP_PACK_58
        WHERE PickSlipNo = @c_Pickslipno
        ORDER BY Orderkey

        OPEN CUR_psno

        FETCH NEXT FROM CUR_psno INTO @c_Orderkey, @c_ExternOrderKey
        WHILE @@FETCH_STATUS <> -1
        BEGIN
            INSERT INTO #TMP_PACK_58_1
            (OrderKey, ExternOrderKey, PickSlipNo, OIPlatform, DelDate, Contact1,SKU,ManufacturerSKU,
             Notes,Qty,CUDF02,PHBarcode,OSBarcode,EXTORDBarcode,Recgroup,ShowNo)
             SELECT OrderKey,ExternOrderKey,PickSlipNo,OIPlatform,DelDate,Contact1,SKU,ManufacturerSKU,
             Notes,Qty,CUDF02,PHBarcode,OSBarcode,EXTORDBarcode,
             (Row_Number() OVER (PARTITION BY ORDERKEY ORDER BY Orderkey Asc)-1)/@n_MaxLineno+1 AS recgroup,
             'Y'
            FROM #TMP_PACK_58 WHERE ExternOrderkey = @c_ExternOrderKey AND ORDERKEY =  @c_Orderkey

        SELECT @n_MaxRec = COUNT(rowid) FROM #TMP_PACK_58 WHERE ExternOrderkey = @c_ExternOrderKey AND ORDERKEY =  @c_Orderkey

        SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno

        WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)
        BEGIN
            INSERT INTO #TMP_PACK_58_1
            (OrderKey, ExternOrderKey, PickSlipNo, OIPlatform, DelDate, Contact1,
             CUDF02, PHBarcode, OSBarcode, EXTORDBarcode, RECGROUP,ShowNo)
            SELECT TOP 1 OrderKey, ExternOrderKey, PickSlipNo, OIPlatform, DelDate, Contact1,
            CUDF02, PHBarcode, OSBarcode, EXTORDBarcode, RECGROUP,'N'
            FROM #TMP_PACK_58_1 WHERE ExternOrderkey = @c_ExternOrderKey AND ORDERKEY =  @c_Orderkey
            ORDER BY ROWID DESC

             SET @n_CurrentRec = @n_CurrentRec + 1
        END

        SET @n_MaxRec = 0
        SET @n_CurrentRec = 0

        FETCH NEXT FROM CUR_psno INTO @c_Orderkey, @c_ExternOrderKey
        END
        CLOSE CUR_psno
        DEALLOCATE CUR_psno
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

  SELECT   Orderkey
         , ExternOrderkey
         , PickSlipNo
         , OIPlatform
         , DelDate
         , Contact1
         , SKU
         , ManufacturerSKU
         , Notes
         , Qty
         , CUDF02
         , PHBarcode
         , OSBarcode
         , EXTORDBarcode
         , @c_RptLogo AS RptLogo
         , ShowNo
  FROM #TMP_PACK_58_1
  ORDER BY ROWID
         , Orderkey

   IF OBJECT_ID('tempdb..##TMP_PACK_58') IS NOT NULL
      DROP TABLE #TMP_PACK_58

   IF OBJECT_ID('tempdb..##TMP_PACK_58_1') IS NOT NULL
      DROP TABLE #TMP_PACK_58_1

END -- procedure

GO