SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_PackListBySku27                                     */
/* Creation Date: 28-DEC-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS-21424 - [TW] SHDEC B2B Packing List New                  */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_sku27                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 28-DEC-2022  CSCHONG   1.0 Devops Scripts Combine                    */
/* 26-MAY-2023  CSCHONG   1.1 WMS-22552 add new field (CS01)            */
/************************************************************************/

CREATE   PROC [dbo].[isp_PackListBySku27]
            @c_pickslipno     NVARCHAR(10)
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
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_GetStorerkey    NVARCHAR(15)

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
         , @c_RptLogo         NVARCHAR(255)
         , @c_QRCode          NVARCHAR(255)
         , @c_sku             NVARCHAR(20)
         , @c_sorting         NVARCHAR(10)   

  DECLARE

           @C_col01         NVARCHAR(10)
         , @n_Col01         INT
         , @c_Col01_Field   NVARCHAR(60)
         , @n_Col02         INT
         , @c_Col02_Field   NVARCHAR(60)
         , @n_Col03         INT
         , @c_Col03_Field   NVARCHAR(60)
         , @c_ExecArguments nvarchar(MAX)
         , @c_output_Field  NVARCHAR(60)
         , @sql             nvarchar(max)
         , @c_dropid        NVARCHAR(20)    --CS01

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
   SET @n_MaxLineno = 8
   SET @n_PrnQty    = 1
   SET @n_MaxId     = 1
   SET @n_MaxRec    = 1
   SET @n_CurrentRec= 1
   SET @n_Page      = 1
   SET @n_getPageno = 1
   SET @c_recgroup  = 1

   CREATE TABLE #TMP_PCKBYSKU27_1
      ( Loadkey      NVARCHAR(10)   NOT NULL
      , Orderkey     NVARCHAR(10)   NOT NULL
      , PickSlipNo   NVARCHAR(10)   NOT NULL
      , Storerkey    NVARCHAR(15)   NOT NULL
      )

   CREATE TABLE #TMP_PCKBYSKU27
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
      , QRCode            NVARCHAR(250) NULL
      , RPTTITLE1         NVARCHAR(100) NULL
      , RPTTITLE2         NVARCHAR(100) NULL
      , LOTT02            NVARCHAR(18) NULL
      , ODUDF10           NVARCHAR(50) NULL
      , Storerkey         NVARCHAR(20) NULL
      , OTHSKU            NVARCHAR(20) NULL
      )

   SET @c_Facility = ''
   SELECT TOP 1 @c_Facility = LP.Facility
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN PackHeader PH WITH (NOLOCK) ON PH.LoadKey=LP.LoadKey
   WHERE PH.PickSlipNo = @c_pickslipno

   SELECT TOP 1 @c_RptLogo = ISNULL(CL2.Long,''),
                @c_QRCode  = ISNULL(CL2.UDF01,'')
   FROM ORDERS ORD (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey
   JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'RPTLogo' AND CL2.Storerkey = ORD.storerkey AND CL2.Code = ORD.OrderGroup
   WHERE PH.PickSlipNo = @c_pickslipno


   --CS01 S

    SELECT TOP 1 @c_dropid = PD.DropID
    FROM dbo.PackDetail PD WITH (NOLOCK)
    WHERE PD.PickSlipNo=@c_pickslipno 

   --CS01 E

   INSERT INTO #TMP_PCKBYSKU27_1
      ( Loadkey
      , Orderkey
      , PickSlipNo
      , Storerkey
      )

   SELECT DISTINCT
          ORD.Loadkey
         ,ORD.Orderkey
         ,PH.PickSlipNo
         ,ORD.Storerkey
   FROM ORDERS ORD (NOLOCK) 
   JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey
   WHERE PH.PickSlipNo = @c_pickslipno

QUIT_SP:

      INSERT INTO #TMP_PCKBYSKU27
      (
          Orderkey,
          OrdDate,
          PickSlipNo,
          OIPlatform,
          EditDate,
          Contact1,
          SKU,
          RetailSKU,
          Notes,
          Qty,
          CUDF01,
          PHBarcode,
          OSBarcode,
          EcomOrdIDBarcode,
          RPTLOGO,
          EcomOrdID,
          PLOC,
          SDESCR,
          Notes2,
          ReferenceId,
          SSIZE,
          QRCode,
          RPTTITLE1,
          RPTTITLE2,
          LOTT02,
          ODUDF10,
          Storerkey,
          OTHSKU)
      SELECT  OS.ORDERKEY
            , OS.OrderDate
            , t.Pickslipno
            , ISNULL(CL2.[UDF01],'')
            , OS.EditDate
            , ISNULL(OS.C_CONTACT1,'')
            , SKU.sku
           -- , SKU.RetailSKU
            , OD.Userdefine01
            , ISNULL(CL3.NOTES,'')
            , SUM(PID.Qty)
            , ISNULL(CL1.UDF01,'')
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(t.PICKSLIPNO)))
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(OS.ORDERKEY)))
            , dbo.fn_Encode_IDA_Code128 (LTRIM(RTRIM(ISNULL(OI.Ecomorderid,''))))
            , ISNULL(@c_RptLogo,'')
            , ISNULL(OI.Ecomorderid,'')
            , PID.loc
            , ISNULL(OD.Notes,'')
            , ISNULL(CL4.NOTES,'')
            , ISNULL(OI.ReferenceId,'')
            , ISNULL(SKU.Size,'')
            , ISNULL(@c_QRCode,'') AS QRCode
            , ISNULL(CL5.UDF01,'')
            , ISNULL(CL5.UDF02,'')
            , LOTT.lottable02
            , ISNULL(OD.UserDefine10,'')
            , t.Storerkey
            , ''
      FROM #TMP_PCKBYSKU27_1 t
      JOIN ORDERS OS (NOLOCK) ON t.Orderkey = OS.OrderKey
      LEFT JOIN ORDERINFO OI (NOLOCK) ON OS.ORDERKEY = OI.ORDERKEY
      JOIN ORDERDETAIL OD(NOLOCK) ON OD.ORDERKEY = OS.ORDERKEY
      JOIN PICKDETAIL PID (NOLOCk) ON PID.Orderkey = OD.Orderkey AND PID.SKU = OD.SKU AND PID.OrderLineNumber = OD.OrderLineNumber
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = PID.lot and LOTT.sku = PID.SKU AND LOTT.Storerkey = PID.Storerkey
      JOIN SKU (NOLOCK) ON OD.SKU = SKU.SKU AND OD.STORERKEY = SKU.STORERKEY
      LEFT JOIN CODELKUP CL1 (NOLOCK) ON OS.STORERKEY = CL1.STORERKEY AND CL1.LISTNAME ='ECDLMODE' and CL1.Code = OS.Shipperkey
      LEFT JOIN CODELKUP CL2 (NOLOCK) ON OS.STORERKEY = CL2.STORERKEY AND CL2.LISTNAME ='PLATFORM' and CL2.Code = OI.Platform
      LEFT JOIN CODELKUP CL3 (NOLOCK) ON OS.STORERKEY = CL3.STORERKEY AND CL3.LISTNAME ='REPORTCFG' and CL3.Code= OI.Platform and CL3.Code2 = '01'
      LEFT JOIN CODELKUP CL4 (NOLOCK) ON OS.STORERKEY = CL4.STORERKEY AND CL4.LISTNAME ='REPORTCFG' and CL4.Code= OI.Platform and CL4.Code2 = '02'
      LEFT JOIN CODELKUP CL5 (NOLOCK) ON OS.STORERKEY = CL5.STORERKEY AND CL5.LISTNAME ='REPORTCFG' and CL5.Code = '03'
      WHERE t.PickSlipNo = @c_pickslipno
      GROUP BY OS.ORDERKEY
            , OS.OrderDate
            , t.Pickslipno
            , ISNULL(CL2.[UDF01],'')
            , OS.EditDate
            , ISNULL(OS.C_CONTACT1,'')
            , SKU.sku
            , OD.Userdefine01
            , ISNULL(CL3.NOTES,'')
            , ISNULL(CL1.UDF01,'')
            , ISNULL(OI.Ecomorderid,'')
            , PID.Loc
            , ISNULL(OD.Notes,'')
            , ISNULL(CL4.NOTES,'')
            , ISNULL(OI.ReferenceId,'')
            , ISNULL(SKU.Size,'')
            , ISNULL(CL5.UDF01,'')
            , ISNULL(CL5.UDF02,'')
            , LOTT.lottable02
            , ISNULL(OD.UserDefine10,'')
            , t.Storerkey
      ORDER BY t.Pickslipno
            ,  OS.ORDERKEY
            ,  PID.loc

        SET   @C_col01    = ''
        SET   @n_Col01    = ''
        SET   @c_Col01_Field  = ''
        SET   @n_Col02        = ''
        SET   @c_Col02_Field  = ''
        SET   @n_Col03        = ''
        SET   @c_Col03_Field  = ''
        SET   @c_GetStorerkey  = ''

SELECT TOP 1 @c_GetStorerkey = t.Storerkey
FROM #TMP_PCKBYSKU27_1 t
Where t.PickSlipNo = @c_pickslipno


SELECT
                  @n_Col01      = ISNULL(MAX(CASE WHEN Code = 'Col01' THEN 1 ELSE 0 END),0)
               ,  @c_Col01_Field= ISNULL(MAX(CASE WHEN Code = 'Col01' THEN UDF02 ELSE '' END),'')
               ,  @n_Col02      = ISNULL(MAX(CASE WHEN Code = 'Col02' THEN 1 ELSE 0 END),0)
               ,  @c_Col02_Field= ISNULL(MAX(CASE WHEN Code = 'Col02' THEN UDF02 ELSE '' END),'')
               ,  @n_Col03      = ISNULL(MAX(CASE WHEN Code = 'Col03' THEN 1 ELSE 0 END),0)
               ,  @c_Col03_Field= ISNULL(MAX(CASE WHEN Code = 'Col03' THEN UDF02 ELSE '' END),'')
            FROM CODELKUP WITH (NOLOCK)
            WHERE ListName = 'REPORTCFG'
            AND   Storerkey = @c_GetStorerkey
            AND   Long = 'r_dw_packing_list_by_sku27'
            AND   ISNULL(Short,'') <> 'N'
  

  IF EXISTS(SELECT LONG FROM CODELKUP(NOLOCK) WHERE LISTNAME = 'REPORTCFG' AND CODE = 'SortByLogicalPlatform' 
                                                AND STORERKEY = @c_GetStorerkey AND Code2 = 'r_dw_packing_list_by_sku27')
  BEGIN
     SET @c_sorting = 'Y'
  END
  ELSE 
  BEGIN
     SET @c_sorting = 'N'
  END


  DECLARE CUR_GETOTHSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickSlipNo
         ,OrderKey
         ,Storerkey
         ,SKU
   FROM #TMP_PCKBYSKU27
   ORDER BY PickSlipNo

   OPEN CUR_GETOTHSKU

   FETCH NEXT FROM CUR_GETOTHSKU INTO @c_PickSlipNo
                                ,@c_Orderkey
                                ,@c_Storerkey
                                ,@c_sku
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @c_Col01_Field <> '' AND @c_Col02_Field <>'' AND @c_Col03_Field <> ''   
      BEGIN

        SET   @c_ExecArguments = ''
        SET   @c_output_Field  =''
        SET   @sql             =''

         select @sql = '
                        select top 10 @c_output_Field =
                        case when isnull('+@c_Col01_Field+','''') <> '''' then '+@c_Col01_Field+'
                        else
                        case when isnull('+@c_Col02_Field+' ,'''') <> '''' then '+@c_Col02_Field+'
                        else
                        case when isnull('+@c_Col03_Field+' ,'''')<>'''' then '+@c_Col03_Field+'
                        else '''' end end end
                        from sku (nolock) where storerkey = @c_Storerkey and  sku= @c_Sku'

        SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(50) , @c_Sku NVARCHAR(20), @c_output_Field NVARCHAR(60) OUTPUT '

        EXEC sp_executesql @sql
            , @c_ExecArguments
            , @c_Storerkey
            , @c_Sku
            , @c_output_Field OUTPUT
    END
    ELSE
    BEGIN
       SET @c_output_Field =''
    END
  
   UPDATE #TMP_PCKBYSKU27
   SET OTHSKU = @c_output_Field
   WHERE PickSlipNo = @c_PickSlipNo
   AND  Orderkey = @c_Orderkey
   AND  SKU = @c_sku
   AND Storerkey = @c_Storerkey

   FETCH NEXT FROM CUR_GETOTHSKU INTO @c_PickSlipNo
                                   ,@c_Orderkey
                                   ,@c_Storerkey
                                   ,@c_sku
   END
   CLOSE CUR_GETOTHSKU
   DEALLOCATE CUR_GETOTHSKU

   IF @c_sorting = 'Y'
      SELECT  Orderkey
            , OrdDate
            , PickSlipNo
            , OIPlatform
            , EditDate
            , Contact1
            , SKU
            , ISNULL(RetailSKU,'') AS RetailSKU
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
            , QRCode
            , RPTTITLE1
            , RPTTITLE2
            , LOTT02
            , ODUDF10
            , storerkey
            , OTHSKU
            , @c_dropid AS Dropid     --CS01
      FROM #TMP_PCKBYSKU27
      ORDER BY OIPlatform,PickSlipNo,Orderkey,PLOC
      ELSE 
         SELECT  Orderkey
            , OrdDate
            , PickSlipNo
            , OIPlatform
            , EditDate
            , Contact1
            , SKU
            , ISNULL(RetailSKU,'') AS RetailSKU
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
            , QRCode
            , RPTTITLE1
            , RPTTITLE2
            , LOTT02
            , ODUDF10
            , storerkey
            , OTHSKU
            , @c_dropid AS Dropid     --CS01
      FROM #TMP_PCKBYSKU27
      ORDER BY PickSlipNo,Orderkey,PLOC



QUIT_RESULT:
END -- procedure

SET QUOTED_IDENTIFIER OFF

GO