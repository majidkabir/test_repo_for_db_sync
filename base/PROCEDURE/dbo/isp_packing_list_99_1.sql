SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc: isp_Packing_List_99_1                                   */
/* Creation Date: 18-Mar-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: copy from isp_Packing_List_64_1                          */
/*                                                                      */
/* Purpose:WMS-16416 [TW] MLB PACKLIST Rcmreport CR                     */
/*        :                                                             */
/* Called By:r_dw_packing_list_99_1    (ECOM)                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 28-Sep-2021  Mingle    1.0 DevOps Combine Script                     */
/* 12-Aug-2022  Mingle    1.1 WMS-20386 add new mappings(ML01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_99_1]
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
		 --START ML01
		 , @c_H01             NVARCHAR(255) = ''
		 , @c_H02             NVARCHAR(255) = ''
		 , @c_D01             NVARCHAR(255) = ''
		 , @c_D02             NVARCHAR(255) = ''
		 , @c_D03             NVARCHAR(255) = ''
		 , @c_D04             NVARCHAR(255) = ''
		 , @c_D05             NVARCHAR(255) = ''
		 , @c_D06             NVARCHAR(255) = ''
		 , @c_D07             NVARCHAR(255) = ''
		 , @c_D08             NVARCHAR(255) = ''
		 , @c_D09             NVARCHAR(255) = ''
		 , @c_D10             NVARCHAR(255) = ''
		 , @c_D11             NVARCHAR(255) = ''
		 , @c_D12             NVARCHAR(255) = ''
		 , @c_D13             NVARCHAR(255) = ''
		 , @c_D14             NVARCHAR(255) = ''
		 , @c_QRCODE          NVARCHAR(255) = ''
		 --END ML01

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

   CREATE TABLE #TMP_PACK_58
      ( rowid             INT NOT NULL identity(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NOT NULL
      , ExternOrderkey    NVARCHAR(50)   NULL
      , PickSlipNo        NVARCHAR(10)   NOT NULL
      , OIPlatform        NVARCHAR(40)
      , DelDate           DATETIME
      , Contact1          NVARCHAR(45)   NULL
      , SKU               NVARCHAR(20)   NULL
      , ManufacturerSKU   NVARCHAR(20)   NULL
      , Notes             NVARCHAR(255)  NULL
      , Qty               INT
      , CUDF02            NVARCHAR(255)  NULL
      , PHBarcode         NVARCHAR(100)
      , OSBarcode         NVARCHAR(100)
      , EXTORDBarcode     NVARCHAR(100)
      , RPTLOGO           NVARCHAR(255)
      )

      CREATE TABLE #TMP_PACK_58_1
      ( rowid             INT NOT NULL identity(1,1) PRIMARY KEY
      , Orderkey          NVARCHAR(10)   NOT NULL
      , ExternOrderkey    NVARCHAR(50)   NULL
      , PickSlipNo        NVARCHAR(10)   NOT NULL
      , OIPlatform        NVARCHAR(40)
      , DelDate           DATETIME
      , Contact1          NVARCHAR(45)   NULL
      , SKU               NVARCHAR(20) NULL
      , ManufacturerSKU   NVARCHAR(20)   NULL
      , Notes             NVARCHAR(255)  NULL
      , Qty               INT
      , CUDF02            NVARCHAR(255)  NULL
      , PHBarcode         NVARCHAR(100)
      , OSBarcode         NVARCHAR(100)
      , EXTORDBarcode     NVARCHAR(100)
      , recgroup          INT NULL
      , ShowNo            NVARCHAR(1)
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

	  --START ML01
	  IF( @n_Continue = 1 OR @n_Continue = 2)
      BEGIN
		  SELECT @c_H01 = MAX(CASE WHEN CLR.CODE2 = 'H01' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_H02 = MAX(CASE WHEN CLR.CODE2 = 'H02' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D01 = MAX(CASE WHEN CLR.CODE2 = 'D01' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D02 = MAX(CASE WHEN CLR.CODE2 = 'D02' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D03 = MAX(CASE WHEN CLR.CODE2 = 'D03' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D04 = MAX(CASE WHEN CLR.CODE2 = 'D04' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D05 = MAX(CASE WHEN CLR.CODE2 = 'D05' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D06 = MAX(CASE WHEN CLR.CODE2 = 'D06' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D07 = MAX(CASE WHEN CLR.CODE2 = 'D07' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D08 = MAX(CASE WHEN CLR.CODE2 = 'D08' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D09 = MAX(CASE WHEN CLR.CODE2 = 'D09' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D10 = MAX(CASE WHEN CLR.CODE2 = 'D10' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D11 = MAX(CASE WHEN CLR.CODE2 = 'D11' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D12 = MAX(CASE WHEN CLR.CODE2 = 'D12' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D13 = MAX(CASE WHEN CLR.CODE2 = 'D13' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_D14 = MAX(CASE WHEN CLR.CODE2 = 'D14' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
			 ,@c_QRCODE = MAX(CASE WHEN CLR.CODE2 = 'QRCODE' THEN ISNULL(CLR.NOTES,'') ELSE '' END)
		  FROM CODELKUP CLR WITH (NOLOCK)    
		  WHERE CLR.LISTNAME='REPORTCFG' AND CLR.Storerkey=(SELECT TOP 1 STORERKEY FROM PACKHEADER (NOLOCK) WHERE PICKSLIPNO = @c_Pickslipno )
		  AND CLR.CODE = 'ECOM' 
	  END
	  --END ML01

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

        select @n_MaxRec = COUNT(rowid) from #TMP_PACK_58 WHERE ExternOrderkey = @c_ExternOrderKey AND ORDERKEY =  @c_Orderkey

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
         , @c_RptLogo as RptLogo
         , ShowNo
		 --START ML01
		 ,  @c_H01
			 ,  @c_H02
			 ,  @c_D01
			 ,  @c_D02
			 ,  @c_D03
			 ,  @c_D04
			 ,  @c_D05
			 ,  @c_D06
			 ,  @c_D07
			 ,  @c_D08
			 ,  @c_D09
			 ,  @c_D10
			 ,  @c_D11
			 ,  @c_D12
			 ,  @c_D13
			 ,  @c_D14
			 ,  @c_QRCODE
		  --END ML01
  FROM #TMP_PACK_58_1
  ORDER BY ROWID
         , Orderkey

  IF OBJECT_ID('tempdb..##TMP_PACK_58') IS NOT NULL
   DROP TABLE #TMP_PACK_58

  IF OBJECT_ID('tempdb..##TMP_PACK_58_1') IS NOT NULL
   DROP TABLE #TMP_PACK_58_1

END -- procedure


GO