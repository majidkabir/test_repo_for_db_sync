SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Store Procedure: isp_r_hk_carton_label_09                             */
/* Creation Date: 24-Apr-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: WMS-4791 - Copy from nsp_UCC_CartonLabel_40 for Skechers     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_carton_label_09             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Purposes                                         */
/* 27/08/2018  ML       WMS-6130  Update Route logic for Converse        */
/* 29/11/2018  ML       WMS-7117  Add generic route code                 */
/* 04/01/2019  ML       WMS-7468  Add ReportCfg ShowFields               */
/* 05/03/2021  ML       WMS-16440 Add MapField: UDF04ShowBarcode         */
/* 18/03/2021  ML       WMS-16440 Add MapField: UserDefine04             */
/* 10/06/2021  ML       WMS-17263 Change all fields Configurable         */
/* 24/06/2021  ML       Handle printing from both EXceed and RDT         */
/* 23/03/2022  ML       Add NULL to Temp Table                           */
/* 11/10/2022  ML       Change default ShipFrom to 'From :  MCL'         */
/*************************************************************************/
-- From EXceed Packing: PickSlipNo, CartonNoStart, CartonNoEnd, LabelNoStart, LabelNoEnd
-- From RDT: Storerkey, PickSlipNo/Orderkey/ExtOrderkey, CartonNoStart, CartonNoEnd, LabelNoStart, LabelNoEnd
CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_09] (
   @c_StorerKey     NVARCHAR(50)
 , @c_PickSlipNo    NVARCHAR(50)
 , @c_CartonNoStart NVARCHAR(50)
 , @c_CartonNoEnd   NVARCHAR(50)
 , @c_LabelNoStart  NVARCHAR(50) = ''
 , @c_LabelNoEnd    NVARCHAR(50) = ''
)
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      LabelNo, LabelNo_Format, ExternOrderKey, UserDefine04, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, ConsigneeKey
      Route, C_Zip, C_Contact, CartonType, OrderKey, DeliveryDate, ZipCodeFrom, UDF04ShowBarcode, CartonNo, ShipFrom, TrackingNo, TrackingNo_Format
      T_ExternOrderkey, T_Orderkey, T_DeliveryDate, T_Consignee

   [MAPVALUE]

   [SHOWFIELD]
      GenericRoute

   [SQLJOIN]
*/

   DECLARE @c_Temp             NVARCHAR(50) = ''
         , @c_ExtOrderkeyStart NVARCHAR(50) = ''
         , @c_ExtOrderkeyEnd   NVARCHAR(50) = ''
         , @c_OrderkeyStart    NVARCHAR(50) = ''
         , @c_OrderkeyEnd      NVARCHAR(50) = ''

   IF LEFT(@c_StorerKey, 1) = 'P'          -- Print from EXceed Packing Module
   BEGIN
      SET @c_LabelNoEnd    = @c_LabelNoStart
      SET @c_LabelNoStart  = @c_CartonNoEnd
      SET @c_CartonNoEnd   = @c_CartonNoStart
      SET @c_CartonNoStart = @c_PickSlipNo
      SET @c_PickSlipNo    = @c_StorerKey
      SET @c_StorerKey     = ''
      SELECT TOP 1 @c_StorerKey = Storerkey
        FROM dbo.PACKHEADER (NOLOCK)
       WHERE PickslipNo = @c_PickSlipNo
   END
   ELSE IF LEFT(@c_PickSlipNo, 1) <> 'P'   -- Print from RDT
   BEGIN
      IF CHARINDEX('-',@c_PickSlipNo) > 0
      BEGIN
         --To retrieve Orderkey/ExternOrderKey Start
         SET @c_Temp = SUBSTRING(@c_PickSlipNo, 1, CHARINDEX('-',@c_PickSlipNo)-1)
         IF EXISTS(SELECT TOP 1 1 FROM dbo.ORDERS(NOLOCK) WHERE Orderkey=@c_Temp)
            SET @c_OrderkeyStart = @c_Temp
         ELSE
            SET @c_ExtOrderkeyStart = @c_Temp

         --To retrieve Orderkey/ExternOrderKey End
         SET @c_Temp = SUBSTRING(@c_PickSlipNo, CHARINDEX('-',@c_PickSlipNo)+1, LEN(@c_PickSlipNo))
         IF EXISTS(SELECT TOP 1 1 FROM dbo.ORDERS(NOLOCK) WHERE Orderkey=@c_Temp)
            SET @c_OrderkeyEnd  = @c_Temp
         ELSE
            SET @c_ExtOrderkeyEnd = @c_Temp
      END
      ELSE
      BEGIN
         IF EXISTS(SELECT TOP 1 1 FROM dbo.ORDERS(NOLOCK) WHERE Orderkey=@c_PickSlipNo)
         BEGIN
            SET @c_OrderkeyStart = @c_PickSlipNo
            SET @c_OrderkeyEnd   = @c_PickSlipNo
         END
         ELSE
         BEGIN
            SET @c_ExtOrderkeyStart = @c_PickSlipNo
            SET @c_ExtOrderkeyEnd   = @c_PickSlipNo
         END
      END
      SET @c_PickSlipNo = ''
   END


   DECLARE @c_DataWindow          NVARCHAR(40) = 'r_hk_carton_label_09'
         , @c_ExecStatements      NVARCHAR(MAX)
         , @c_ExecArguments       NVARCHAR(MAX)
         , @c_JoinClause          NVARCHAR(MAX)
         , @c_LabelNoExp          NVARCHAR(MAX)
         , @c_LabelNo_FormatExp   NVARCHAR(MAX)
         , @c_ExternOrderKeyExp   NVARCHAR(MAX)
         , @c_CartonNoExp         NVARCHAR(MAX)
         , @c_UserDefine04Exp     NVARCHAR(MAX)
         , @c_C_CompanyExp        NVARCHAR(MAX)
         , @c_C_Address1Exp       NVARCHAR(MAX)
         , @c_C_Address2Exp       NVARCHAR(MAX)
         , @c_C_Address3Exp       NVARCHAR(MAX)
         , @c_C_Address4Exp       NVARCHAR(MAX)
         , @c_ConsigneeKeyExp     NVARCHAR(MAX)
         , @c_RouteExp            NVARCHAR(MAX)
         , @c_C_ZipExp            NVARCHAR(MAX)
         , @c_C_ContactExp        NVARCHAR(MAX)
         , @c_CartonTypeExp       NVARCHAR(MAX)
         , @c_OrderKeyExp         NVARCHAR(MAX)
         , @c_DeliveryDateExp     NVARCHAR(MAX)
         , @c_ZipCodeFromExp      NVARCHAR(MAX)
         , @c_UDF04ShowBarcodeExp NVARCHAR(MAX)
         , @c_ShipFromExp         NVARCHAR(MAX)
         , @c_TrackingNoExp       NVARCHAR(MAX)
         , @c_TrackingNo_FmtExp   NVARCHAR(MAX)
         , @c_Lbl_ExtOrderkeyExp  NVARCHAR(MAX)
         , @c_Lbl_OrderkeyExp     NVARCHAR(MAX)
         , @c_Lbl_DeliveryDateExp NVARCHAR(MAX)
         , @c_Lbl_ConsigneeExp    NVARCHAR(MAX)

   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT

   CREATE TABLE #TEMP_RESULT (
        PickSlipNo        NVARCHAR(500)  NULL
      , LabelNo           NVARCHAR(500)  NULL
      , LabelNo_Format    NVARCHAR(500)  NULL
      , ExternOrderKey    NVARCHAR(500)  NULL
      , CartonNo          INT            NULL
      , CartonNoText      NVARCHAR(500)  NULL
      , Userdefine04      NVARCHAR(500)  NULL
      , C_Company         NVARCHAR(500)  NULL
      , C_Address1        NVARCHAR(500)  NULL
      , C_Address2        NVARCHAR(500)  NULL
      , C_Address3        NVARCHAR(500)  NULL
      , C_Address4        NVARCHAR(500)  NULL
      , ConsigneeKey      NVARCHAR(500)  NULL
      , Route             NVARCHAR(500)  NULL
      , C_Zip             NVARCHAR(500)  NULL
      , SysDate           NVARCHAR(500)  NULL
      , C_Contact         NVARCHAR(500)  NULL
      , CartonType        NVARCHAR(500)  NULL
      , OrderKey          NVARCHAR(500)  NULL
      , DeliveryDate      NVARCHAR(500)  NULL
      , ZipCodeFrom       NVARCHAR(500)  NULL
      , ShowFields        NVARCHAR(4000) NULL
      , UDF04ShowBarcode  NVARCHAR(500)  NULL
      , ShipFrom          NVARCHAR(500)  NULL
      , TrackingNo        NVARCHAR(500)  NULL
      , TrackingNo_Format NVARCHAR(500)  NULL
      , Lbl_ExtOrderkey   NVARCHAR(500)  NULL
      , Lbl_Orderkey      NVARCHAR(500)  NULL
      , Lbl_DeliveryDate  NVARCHAR(500)  NULL
      , Lbl_Consignee     NVARCHAR(500)  NULL
   )

   SELECT @c_JoinClause          = ''
        , @c_LabelNoExp          = ''
        , @c_LabelNo_FormatExp   = ''
        , @c_ExternOrderKeyExp   = ''
        , @c_CartonNoExp         = ''
        , @c_UserDefine04Exp     = ''
        , @c_C_CompanyExp        = ''
        , @c_C_Address1Exp       = ''
        , @c_C_Address2Exp       = ''
        , @c_C_Address3Exp       = ''
        , @c_C_Address4Exp       = ''
        , @c_ConsigneeKeyExp     = ''
        , @c_RouteExp            = ''
        , @c_C_ZipExp            = ''
        , @c_C_ContactExp        = ''
        , @c_CartonTypeExp       = ''
        , @c_OrderKeyExp         = ''
        , @c_DeliveryDateExp     = ''
        , @c_ZipCodeFromExp      = ''
        , @c_UDF04ShowBarcodeExp = ''
        , @c_ShipFromExp         = ''
        , @c_TrackingNoExp       = ''
        , @c_TrackingNo_FmtExp   = ''
        , @c_Lbl_ExtOrderkeyExp  = ''
        , @c_Lbl_OrderkeyExp     = ''
        , @c_Lbl_DeliveryDateExp = ''
        , @c_Lbl_ConsigneeExp    = ''


   SELECT TOP 1
          @c_JoinClause = Notes
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @c_Storerkey
    ORDER BY Code2


   SELECT TOP 1
          @c_LabelNoExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='LabelNo')), '' )
        , @c_LabelNo_FormatExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='LabelNo_Format')), '' )
        , @c_ExternOrderKeyExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderKey')), '' )
        , @c_CartonNoExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='CartonNo')), '' )
        , @c_UserDefine04Exp     = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='UserDefine04')), '' )
        , @c_C_CompanyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )
        , @c_C_Address1Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Address1')), '' )
        , @c_C_Address2Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Address2')), '' )
        , @c_C_Address3Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Address3')), '' )
        , @c_C_Address4Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Address4')), '' )
        , @c_ConsigneeKeyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='ConsigneeKey')), '' )
        , @c_RouteExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )
        , @c_C_ZipExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Zip')), '' )
        , @c_C_ContactExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='C_Contact')), '' )
        , @c_CartonTypeExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='CartonType')), '' )
        , @c_OrderKeyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='OrderKey')), '' )
        , @c_DeliveryDateExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )
        , @c_ZipCodeFromExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='ZipCodeFrom')), '' )
        , @c_UDF04ShowBarcodeExp = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='UDF04ShowBarcode')), '' )
        , @c_ShipFromExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='ShipFrom')), '' )
        , @c_TrackingNoExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='TrackingNo')), '' )
        , @c_TrackingNo_FmtExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='TrackingNo_Format')), '' )
        , @c_Lbl_ExtOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ExternOrderkey')), '' )
        , @c_Lbl_OrderkeyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Orderkey')), '' )
        , @c_Lbl_DeliveryDateExp = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate')), '' )
        , @c_Lbl_ConsigneeExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes)) a, dbo.fnc_DelimSplit(TRIM(UDF01),RTRIM(Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Consignee')), '' )
     FROM dbo.CodeLkup (NOLOCK)
    WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
      AND Storerkey = @c_Storerkey
    ORDER BY Code2


   SET @c_ExecStatements =
      N'INSERT INTO #TEMP_RESULT(PickSlipNo, LabelNo, LabelNo_Format, ExternOrderKey, CartonNo, CartonNoText, Userdefine04, C_Company, C_Address1, C_Address2, C_Address3,'
     +                         ' C_Address4, ConsigneeKey, Route, C_Zip, SysDate, C_Contact, CartonType, OrderKey, DeliveryDate, ZipCodeFrom,'
     +                         ' ShowFields, UDF04ShowBarcode, ShipFrom, TrackingNo, TrackingNo_Format, Lbl_ExtOrderkey, Lbl_Orderkey, Lbl_DeliveryDate, Lbl_Consignee)'
     +' SELECT PickSlipNo       = PH.PickSlipNo'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', LabelNo          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNoExp         ,'')<>'' THEN @c_LabelNoExp          ELSE 'PD.LabelNo'         END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', LabelNo_Format   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNo_FormatExp  ,'')<>'' THEN @c_LabelNo_FormatExp   ELSE '''(@@) @ @@ @@@@@ @@@@@@@@@ @''' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', ExternOrderKey   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderKeyExp  ,'')<>'' THEN @c_ExternOrderKeyExp   ELSE 'OH.ExternOrderKey'  END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', CartonNo         = PD.CartonNo'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', CartonNoText     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonNoExp        ,'')<>'' THEN @c_CartonNoExp         ELSE '''Carton ''+CONVERT(VARCHAR(10),PD.CartonNo)' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Userdefine04     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UserDefine04Exp    ,'')<>'' THEN @c_UserDefine04Exp     ELSE 'OH.Userdefine04'    END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Company        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp       ,'')<>'' THEN @c_C_CompanyExp        ELSE 'OH.C_Company'       END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Address1       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address1Exp      ,'')<>'' THEN @c_C_Address1Exp       ELSE 'OH.C_Address1'      END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Address2       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address2Exp      ,'')<>'' THEN @c_C_Address2Exp       ELSE 'OH.C_Address2'      END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Address3       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address3Exp      ,'')<>'' THEN @c_C_Address3Exp       ELSE 'OH.C_Address3'      END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Address4       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address4Exp      ,'')<>'' THEN @c_C_Address4Exp       ELSE 'OH.C_Address4'      END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', ConsigneeKey     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneeKeyExp    ,'')<>'' THEN @c_ConsigneeKeyExp     ELSE 'OH.ConsigneeKey'    END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Route            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp           ,'')<>'' THEN @c_RouteExp            ELSE 'CASE WHEN ISNULL(PH.Route,'''')='''' THEN OH.Route ELSE PH.Route END' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Zip            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ZipExp           ,'')<>'' THEN @c_C_ZipExp            ELSE '''ZIP   ''+ISNULL(OH.C_Zip,'''')' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', SysDate          = CONVERT(VARCHAR(19), CONVERT(VARCHAR(10),GETDATE(),103) + '' '' + CONVERT(VARCHAR(8),GETDATE(),108))'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', C_Contact        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ContactExp       ,'')<>'' THEN @c_C_ContactExp        ELSE ''''''               END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', CartonType       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonTypeExp      ,'')<>'' THEN @c_CartonTypeExp       ELSE 'OH.Type'            END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', OrderKey         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderKeyExp        ,'')<>'' THEN @c_OrderKeyExp         ELSE 'OH.OrderKey'        END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', DeliveryDate     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DeliveryDateExp    ,'')<>'' THEN @c_DeliveryDateExp     ELSE 'CONVERT(NVARCHAR(8),OH.DeliveryDate,3)' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', ZipCodeFrom      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ZipCodeFromExp     ,'')<>'' THEN @c_ZipCodeFromExp      ELSE 'RM.ZipCodeFrom'     END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', ShowFields       = RptCfg.ShowFields'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', UDF04ShowBarcode = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UDF04ShowBarcodeExp,'')<>'' THEN @c_UDF04ShowBarcodeExp ELSE ''''''               END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', ShipFrom         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShipFromExp        ,'')<>'' THEN @c_ShipFromExp         ELSE '''From :  MCL'''    END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', TrackingNo       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TrackingNoExp      ,'')<>'' THEN @c_TrackingNoExp       ELSE '''OH.TrackingNo'''  END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', TrackingNo_Format= ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TrackingNo_FmtExp  ,'')<>'' THEN @c_TrackingNo_FmtExp   ELSE ''''''               END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Lbl_ExtOrderkey  = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_ExtOrderkeyExp ,'')<>'' THEN @c_Lbl_ExtOrderkeyExp  ELSE '''Ext. Order#  :''' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Lbl_Orderkey     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_OrderkeyExp    ,'')<>'' THEN @c_Lbl_OrderkeyExp     ELSE '''WMS Order# :'''   END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Lbl_DeliveryDate = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_DeliveryDateExp,'')<>'' THEN @c_Lbl_DeliveryDateExp ELSE '''Delivery Date:''' END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +      ', Lbl_Consignee    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_ConsigneeExp   ,'')<>'' THEN @c_Lbl_ConsigneeExp    ELSE '''To'''             END + '),'''')'
   SET @c_ExecStatements = @c_ExecStatements
     +  ' FROM dbo.ORDERS     OH (NOLOCK) '
     +  ' JOIN dbo.PACKHEADER PH (NOLOCK) ON OH.OrderKey = PH.OrderKey'
     +  ' JOIN dbo.PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo'
     +  ' LEFT JOIN dbo.ROUTEMASTER RM (NOLOCK) ON OH.Route=RM.Route'
     +  ' LEFT JOIN ('
     +     ' SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))'
     +           ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'
     +       ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''SHOWFIELD'' AND Long=@c_DataWindow AND Short=''Y'''
     +  ' ) RptCfg ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1'
   SET @c_ExecStatements = @c_ExecStatements
       + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

   SET @c_ExecStatements = @c_ExecStatements
     +  ' WHERE OH.StorerKey = @c_StorerKey'
     +    ' AND PD.CartonNo BETWEEN CAST(@c_CartonNoStart AS INT) AND CAST(@c_CartonNoEnd AS INT)'

   IF ISNULL(@c_PickSlipNo,'')='' AND
       ISNULL(@c_OrderkeyStart,'')='' AND ISNULL(@c_OrderkeyEnd,'')='' AND
       ISNULL(@c_ExtOrderkeyStart,'')='' AND ISNULL(@c_ExtOrderkeyEnd,'')=''
      SET @c_ExecStatements = @c_ExecStatements
        +    ' AND 1=2'
   ELSE
   BEGIN
      IF ISNULL(@c_PickSlipNo,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +    ' AND PH.PickSlipNo = @c_PickSlipNo'
      IF ISNULL(@c_OrderkeyStart,'')<>'' OR ISNULL(@c_OrderkeyEnd,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +    ' AND OH.Orderkey BETWEEN @c_OrderkeyStart AND @c_OrderkeyEnd'
      IF ISNULL(@c_ExtOrderkeyStart,'')<>'' OR ISNULL(@c_ExtOrderkeyEnd,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +    ' AND OH.ExternOrderkey BETWEEN @c_ExtOrderkeyStart AND @c_ExtOrderkeyEnd'
      IF ISNULL(@c_LabelNoStart,'')<>'' OR ISNULL(@c_LabelNoEnd,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +    ' AND PD.LabelNo BETWEEN @c_LabelNoStart AND @c_LabelNoEnd'
   END

   SET @c_ExecArguments = N'@c_StorerKey        NVARCHAR(50)'
                        + ',@c_PickSlipNo       NVARCHAR(50)'
                        + ',@c_CartonNoStart    NVARCHAR(50)'
                        + ',@c_CartonNoEnd      NVARCHAR(50)'
                        + ',@c_LabelNoStart     NVARCHAR(50)'
                        + ',@c_LabelNoEnd       NVARCHAR(50)'
                        + ',@c_OrderkeyStart    NVARCHAR(50)'
                        + ',@c_OrderkeyEnd      NVARCHAR(50)'
                        + ',@c_ExtOrderkeyStart NVARCHAR(50)'
                        + ',@c_ExtOrderkeyEnd   NVARCHAR(50)'
                        + ',@c_DataWindow       NVARCHAR(50)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_StorerKey
                    , @c_PickSlipNo
                    , @c_CartonNoStart
                    , @c_CartonNoEnd
                    , @c_LabelNoStart
                    , @c_LabelNoEnd
                    , @c_OrderkeyStart
                    , @c_OrderkeyEnd
                    , @c_ExtOrderkeyStart
                    , @c_ExtOrderkeyEnd
                    , @c_DataWindow


   SELECT PickSlipNo        = X.PickSlipNo
        , LabelNo           = MAX( X.LabelNo )
        , LabelNo_Format    = MAX( X.LabelNo_Format )
        , ExternOrderKey    = MAX( X.ExternOrderKey )
        , CartonNo          = X.CartonNo
        , Userdefine04      = MAX( X.Userdefine04 )
        , C_Company         = MAX( X.C_Company )
        , C_Address1        = MAX( X.C_Address1 )
        , C_Address2        = MAX( X.C_Address2 )
        , C_Address3        = MAX( X.C_Address3 )
        , C_Address4        = MAX( X.C_Address4 )
        , ConsigneeKey      = MAX( X.ConsigneeKey )
        , Route             = MAX( X.Route )
        , C_Zip             = MAX( X.C_Zip )
        , SysDate           = MAX( X.SysDate )
        , C_Contact         = MAX( X.C_Contact )
        , CartonNoText      = MAX( X.CartonNoText )
        , CartonType        = MAX( X.CartonType )
        , OrderKey          = MAX( X.OrderKey )
        , DeliveryDate      = MAX( X.DeliveryDate )
        , ZipCodeFrom       = MAX( X.ZipCodeFrom )
        , ShowFields        = MAX( X.ShowFields )
        , UDF04ShowBarcode  = MAX( X.UDF04ShowBarcode )
        , ShipFrom          = MAX( X.ShipFrom )
        , TrackingNo        = MAX( X.TrackingNo )
        , TrackingNo_Format = MAX( X.TrackingNo_Format )
        , Lbl_ExtOrderkey   = MAX( X.Lbl_ExtOrderkey )
        , Lbl_Orderkey      = MAX( X.Lbl_Orderkey )
        , Lbl_DeliveryDate  = MAX( X.Lbl_DeliveryDate )
        , Lbl_Consignee     = MAX( X.Lbl_Consignee )
   FROM #TEMP_RESULT X
   GROUP BY X.PickSlipNo
          , X.CartonNo
END

GO