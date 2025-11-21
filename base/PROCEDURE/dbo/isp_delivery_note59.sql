SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note59                                  */
/* Creation Date: 01-Apr-2022                                             */
/* Copyright: IDS                                                         */
/* Written by: CSCHONG                                                    */
/*                                                                        */
/* Purpose:WMS-19341 [CN] LOGIUS_Delivery Note_CR                         */
/*                                                                        */
/*                                                                        */
/* Called By: report dw = r_dw_dlivery_note_59                            */
/*                        copy from r_dw_dlivery_note_23_1                */
/*                                                                        */
/* PVCS Version: 1.1                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 01-Apr-2022  CSCHONG   2.5   Devops Scripts Combine                    */
/* 25-Nov-2022  WLChooi   1.1   WMS-21247 - Add ORDERS.Notes2 (WL01)      */
/**************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note59]
(
   @c_MBOLKey  NVARCHAR(21)
 , @c_ShipType NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   --  SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid        INT
         , @n_rowcnt       INT
         , @c_Getmbolkey   NVARCHAR(20)
         , @c_getExtOrdkey NVARCHAR(20)
         , @c_sku          NVARCHAR(20)
         , @c_prev_sku     NVARCHAR(20)
         , @n_ctnSKU       INT
         , @c_pickslipno   NVARCHAR(20)
         , @n_CartonNo     INT
         , @c_multisku     NVARCHAR(1)
         , @n_CtnCount     INT

   DECLARE @c_OrderKey        NVARCHAR(10)
         , @c_pmtterm         NVARCHAR(10)
         , @c_ExtPOKey        NVARCHAR(20)
         , @c_OHUdf05         NVARCHAR(20)
         , @c_MBOLKeyBarcode  NVARCHAR(20)
         , @c_ExternOrdKey    NVARCHAR(30)
         , @c_IDS_Company     NVARCHAR(45)
         , @c_IDS_Address1    NVARCHAR(45)
         , @c_IDS_Address2    NVARCHAR(45)
         , @c_IDS_Address3    NVARCHAR(45)
         , @c_IDS_Address4    NVARCHAR(45)
         , @c_IDS_Phone1      NVARCHAR(18)
         , @c_IDS_City        NVARCHAR(150)
         , @c_BILLTO_Company  NVARCHAR(45)
         , @c_BILLTO_Address1 NVARCHAR(45)
         , @c_BILLTO_Address2 NVARCHAR(45)
         , @c_BILLTO_Address3 NVARCHAR(45)
         , @c_BILLTO_Address4 NVARCHAR(45)
         , @c_BILLTO_City     NVARCHAR(150)
         , @c_ShipTO_Company  NVARCHAR(45)
         , @c_ShipTO_Address1 NVARCHAR(45)
         , @c_ShipTO_Address2 NVARCHAR(45)
         , @c_ShipTO_Address3 NVARCHAR(45)
         , @c_ShipTO_Address4 NVARCHAR(45)
         , @c_ShipTO_City     NVARCHAR(150)
         , @c_ShipTO_Phone1   NVARCHAR(18)
         , @c_ShipTO_Contact1 NVARCHAR(30)
         , @c_ShipTO_Country  NVARCHAR(30)
         , @c_From_Country    NVARCHAR(30)
         , @c_StorerKey       NVARCHAR(15)
         , @c_Descr           NVARCHAR(90)
         , @n_QtyShipped      INT
         , @c_UnitPrice       DECIMAL(10, 2)
         , @c_ShipMode        NVARCHAR(18)
         , @c_SONo            NVARCHAR(30)
         , @c_PCaseCnt        INT
         , @n_PQty            INT
         , @n_PGrossWgt       FLOAT
         , @c_PCubeUom1       FLOAT
         , @c_PalletKey       NVARCHAR(30)
         , @c_ODUDEF05        NVARCHAR(30)
         , @c_CTNCOUNT        INT
         , @n_PieceQty        INT
         , @n_TTLWGT          FLOAT
         , @n_CBM             FLOAT
         , @n_PCubeUom3       FLOAT
         , @c_PNetWgt         FLOAT
         , @n_CtnQty          INT
         , @n_PrevCtnQty      INT
         , @c_CartonType      VARCHAR(10)
         , @n_NoOfCarton      INT
         , @n_NoFullCarton    INT
         , @n_CaseCnt         INT
         , @c_GetPalletKey    NVARCHAR(30)
         , @n_TTLPLT          INT
         , @c_PreOrderKey     NVARCHAR(10)
         , @c_ChkPalletKey    NVARCHAR(30)
         , @c_facility        NVARCHAR(5)
         , @c_OrdGrp          NVARCHAR(20)
         , @n_EPWGT_Value     DECIMAL(6, 2)
         , @n_EPCBM_Value     DECIMAL(6, 2)
         , @c_UDF01           NVARCHAR(5)
         , @n_lineNo          INT
         , @C_CLKUPUDF01      NVARCHAR(15)
         , @C_Lottable11      NVARCHAR(30)
         , @c_madein          NVARCHAR(250)
         , @c_delimiter       NVARCHAR(1)
         , @c_GetOrderKey     NVARCHAR(10)
         , @c_getsku          NVARCHAR(20)
         , @n_CntRec          INT
         , @c_company         NVARCHAR(45)
         , @c_lott11          NVARCHAR(30)
         , @c_UPDATECCOM      NVARCHAR(1)
         , @c_OrderKey_Inv    NVARCHAR(10)
         , @c_CLKUDF01        NVARCHAR(60)   = N''
         , @c_CLKUDF02        NVARCHAR(60)   = N''
         , @c_MSKU            NVARCHAR(20)   = N''
         , @c_FDESCR          NVARCHAR(50)   = N''
         , @c_FADD01          NVARCHAR(45)   = N''
         , @c_FADD02          NVARCHAR(45)   = N''
         , @c_FADD03          NVARCHAR(45)   = N''
         , @c_FADD04          NVARCHAR(45)   = N''
         , @c_FCity           NVARCHAR(45)   = N''
         , @c_modelno         NVARCHAR(30)   = N''
         , @c_Notes2          NVARCHAR(1000) = N'' --WL01


   CREATE TABLE #TEMP_DelNote59
   (
      Rowid           INT            IDENTITY(1, 1)
    , MBOLKey         NVARCHAR(20)   NULL
    , pmtterm         NVARCHAR(10)   NULL
    , ExtPOKey        NVARCHAR(20)   NULL
    , OHUdf05         NVARCHAR(20)   NULL
    , MBOLKeyBarcode  NVARCHAR(20)   NULL
    , ExternOrdKey    NVARCHAR(30)   NULL
    , IDS_Company     NVARCHAR(45)   NULL
    , IDS_Address1    NVARCHAR(45)   NULL
    , IDS_Address2    NVARCHAR(45)   NULL
    , IDS_Address3    NVARCHAR(45)   NULL
    , IDS_Address4    NVARCHAR(45)   NULL
    , IDS_Phone1      NVARCHAR(18)   NULL
    , IDS_City        NVARCHAR(150)  NULL
    , BILLTO_Company  NVARCHAR(45)   NULL
    , BILLTO_Address1 NVARCHAR(45)   NULL
    , BILLTO_Address2 NVARCHAR(45)   NULL
    , BILLTO_Address3 NVARCHAR(45)   NULL
    , BILLTO_Address4 NVARCHAR(45)   NULL
    , BILLTO_City     NVARCHAR(150)  NULL
    , ShipTO_Company  NVARCHAR(45)   NULL
    , ShipTO_Address1 NVARCHAR(45)   NULL
    , ShipTO_Address2 NVARCHAR(45)   NULL
    , ShipTO_Address3 NVARCHAR(45)   NULL
    , ShipTO_Address4 NVARCHAR(45)   NULL
    , ShipTO_City     NVARCHAR(150)  NULL
    , ShipTO_Phone1   NVARCHAR(18)   NULL
    , ShipTO_Contact1 NVARCHAR(30)   NULL
    , ShipTO_Country  NVARCHAR(30)   NULL
    , From_Country    NVARCHAR(30)   NULL
    , StorerKey       NVARCHAR(15)   NULL
    , SKU             NVARCHAR(20)   NULL
    , Descr           NVARCHAR(90)   NULL
    , QtyShipped      INT            NULL
    , UnitPrice       DECIMAL(10, 2) NULL
    , ShipMode        NVARCHAR(18)   NULL
    , SONo            NVARCHAR(30)   NULL
    , PCaseCnt        INT
    , Pqty            INT
    , PGrossWgt       FLOAT
    , PCubeUom1       FLOAT
    , PalletKey       NVARCHAR(30)   NULL
    , CTNCOUNT        INT
    , PieceQty        INT
    , TTLWGT          FLOAT
    , CBM             FLOAT
    , PCubeUom3       FLOAT
    , PNetWgt         FLOAT
    , TTLPLT          INT
    , ORDGRP          NVARCHAR(20)   NULL
    , EPWGT           FLOAT
    , EPCBM           FLOAT
    , CLKUPUDF01      NVARCHAR(5)    NULL
    , Orderkey        NVARCHAR(20)   NULL
    , lott11          NVARCHAR(250)  NULL
    , OrderKey_Inv    NVARCHAR(10)   NULL
    , ODUDEF05        NVARCHAR(30)   NULL
    , MSKU            NVARCHAR(20)   NULL
    , FDESCR          NVARCHAR(50)   NULL
    , FADD01          NVARCHAR(45)   NULL
    , FADD02          NVARCHAR(45)   NULL
    , FADD03          NVARCHAR(45)   NULL
    , FADD04          NVARCHAR(45)   NULL
    , FCity           NVARCHAR(45)   NULL
    , Modelno         NVARCHAR(30)   NULL
    , Notes2          NVARCHAR(1000) NULL   --WL01
   )


   CREATE TABLE #TEMP_CTHTYPEDelNote23
   (
      CartonType NVARCHAR(20) NULL
    , SKU        NVARCHAR(20) NULL
    , QTY        INT
    , TotalCtn   INT
    , TotalQty   INT
    , CartonNo   INT
    , Palletkey  NVARCHAR(20) NULL
    , CLKUPUDF01 NVARCHAR(15) NULL
   )

   CREATE TABLE #TEMP_madein23
   (
      MBOLKey   NVARCHAR(20) NULL
    , OrderKey  NVARCHAR(20) NULL
    , SKU       NVARCHAR(20) NULL
    , lot11     NVARCHAR(50) NULL
    , C_Company NVARCHAR(45) NULL
   )


   SET @c_multisku = N'N'
   SET @n_EPWGT_Value = 0.00
   SET @n_EPCBM_Value = 0.00
   SET @n_lineNo = 1
   SET @c_delimiter = N','
   SET @c_UPDATECCOM = N'N'

   DECLARE CS_ORDERS_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ORDERS.OrderKey
                 , CASE WHEN FACILITY.UserDefine06 = 'Y' THEN 'SH' + ISNULL(MBOL.MbolKey, '')
                        ELSE ISNULL(MBOL.MbolKey, '')END AS MBOLKEY
                 , ORDERS.PmtTerm
                 , SUBSTRING(ORDERS.ExternPOKey, 1, 10)
                 , ORDERS.UserDefine05
                 , CASE WHEN FACILITY.UserDefine06 = 'Y' THEN 'SH' + ISNULL(MBOL.MbolKey, '')
                        ELSE NULL END AS BarcodeValue
                 , ORDERS.ExternOrderKey
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Company, '')
                        ELSE ISNULL(S.B_Company, '')END AS IDS_Company
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Address1, '')
                        ELSE ISNULL(S.B_Address1, '')END AS IDS_Address1
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Address2, '')
                        ELSE ISNULL(S.B_Address2, '')END AS IDS_Address2
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Address3, '')
                        ELSE ISNULL(S.B_Address3, '')END AS IDS_Address3
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Address4, '')
                        ELSE ISNULL(S.B_Address4, '')END AS IDS_Address4
                 , CASE WHEN (ISNULL(SOD.Door, '')) <> '' THEN ISNULL(SD.B_Phone1, '')
                        ELSE ISNULL(S.B_Phone1, '')END AS IDS_Phone1
                 , (ISNULL(S.B_City, '') + SPACE(2) + ISNULL(S.B_State, '') + SPACE(2) + ISNULL(S.B_Zip, '')
                    + ISNULL(S.B_Country, '')) AS IDS_City
                 , ORDERS.B_Company AS BILLTO_Company
                 , ISNULL(ORDERS.B_Address1, '') AS BILLTO_Address1
                 , ISNULL(ORDERS.B_Address2, '') AS BILLTO_Address2
                 , ISNULL(ORDERS.B_Address3, '') AS BILLTO_Address3
                 , ISNULL(ORDERS.B_Address4, '') AS BILLTO_Address4
                 , LTRIM(
                      ISNULL(ORDERS.B_City, '') + SPACE(2) + ISNULL(ORDERS.B_State, '') + SPACE(2)
                      + ISNULL(ORDERS.B_Zip, '') + SPACE(2) + ISNULL(ORDERS.B_Country, '')) AS BILLTO_City
                 , ORDERS.C_Company AS ShipTO_Company
                 , ISNULL(ORDERS.C_Address1, '') AS ShipTO_Address1
                 , ISNULL(ORDERS.C_Address2, '') AS ShipTO_Address2
                 , ISNULL(ORDERS.C_Address3, '') AS ShipTO_Address3
                 , ISNULL(ORDERS.C_Address4, '') AS ShipTO_Address4
                 , LTRIM(
                      ISNULL(ORDERS.C_City, '') + SPACE(2) + ISNULL(ORDERS.C_State, '') + SPACE(2)
                      + ISNULL(ORDERS.C_Zip, '') + SPACE(2) + ISNULL(ORDERS.C_Country, '')) AS ShipTO_City
                 , ISNULL(ORDERS.C_Phone1, '') AS ShipTo_phone1
                 , ISNULL(ORDERS.C_contact1, '') AS ShipTo_contact1
                 , ISNULL(ORDERS.C_Country, '') AS ShipTo_country
                 , 'SHANGHAI' AS From_country
                 , ORDERS.StorerKey
                 , ORDERS.UserDefine03 AS ShipMode
                 , ORDERS.UserDefine01 AS SONo
                 , ISNULL(PTD.PalletKey, 'N/A') AS palletkey
                 , ORDERS.Facility
                 , ORDERS.OrderGroup AS OrdGrp
                 , OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.OrderKey
                                       ELSE '' END
                 , ISNULL(FACILITY.Descr, '')
                 , ISNULL(FACILITY.Address1, '')
                 , ISNULL(FACILITY.Address2, '')
                 , ISNULL(FACILITY.Address3, '')
                 , ISNULL(FACILITY.Address4, '')
                 , ISNULL(FACILITY.City, '')
                 , REPLACE(TRIM(ISNULL(ORDERS.Notes2, '')), ', ', ', ' + CHAR(13)) --WL01
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN FACILITY WITH (NOLOCK) ON (FACILITY.Facility = ORDERS.Facility)
   INNER JOIN STORER S WITH (NOLOCK) ON (S.StorerKey = ORDERS.StorerKey)
   LEFT JOIN PALLETDETAIL PTD WITH (NOLOCK) ON PTD.UserDefine03 = ORDERS.MBOLKey AND PTD.UserDefine04 = ORDERS.OrderKey
   LEFT JOIN StorerSODefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey
   LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.StorerKey = SOD.Door)
   WHERE MBOL.MbolKey = @c_MBOLKey

   OPEN CS_ORDERS_INFO

   FETCH FROM CS_ORDERS_INFO
   INTO @c_OrderKey
      , @c_MBOLKey
      , @c_pmtterm
      , @c_ExtPOKey
      , @c_OHUdf05
      , @c_MBOLKeyBarcode
      , @c_ExternOrdKey
      , @c_IDS_Company
      , @c_IDS_Address1
      , @c_IDS_Address2
      , @c_IDS_Address3
      , @c_IDS_Address4
      , @c_IDS_Phone1
      , @c_IDS_City
      , @c_BILLTO_Company
      , @c_BILLTO_Address1
      , @c_BILLTO_Address2
      , @c_BILLTO_Address3
      , @c_BILLTO_Address4
      , @c_BILLTO_City
      , @c_ShipTO_Company
      , @c_ShipTO_Address1
      , @c_ShipTO_Address2
      , @c_ShipTO_Address3
      , @c_ShipTO_Address4
      , @c_ShipTO_City
      , @c_ShipTO_Phone1
      , @c_ShipTO_Contact1
      , @c_ShipTO_Country
      , @c_From_Country
      , @c_StorerKey
      , @c_ShipMode
      , @c_SONo
      , @c_PalletKey
      , @c_facility
      , @c_OrdGrp
      , @c_OrderKey_Inv
      , @c_FDESCR
      , @c_FADD01
      , @c_FADD02
      , @c_FADD03
      , @c_FADD04
      , @c_FCity
      , @c_Notes2 --WL01

   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Full Carton
      SET @n_PrevCtnQty = 0

      IF @c_facility IN ( 'BULIM', 'WGQAP', 'WGQBL', 'WGQUS' )
      BEGIN
         INSERT INTO #TEMP_CTHTYPEDelNote23 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo, Palletkey, CLKUPUDF01)
         SELECT 'SINGLE'
              , PD.SKU
              , SUM(PD.Qty) / COUNT(DISTINCT PD.CartonNo)
              , COUNT(DISTINCT PD.CartonNo)
              , SUM(PD.Qty)
              , 0
              , CASE WHEN C.UDF01 = 'P' THEN
                        ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'), '')
                     ELSE 'N/A' END
              , ISNULL(C.UDF01, '')
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
         JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo AND PLTD.Sku = PD.SKU
         JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
         JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                            AND C.UDF01 = 'P'
                                            AND C.Code = CON.ContainerType
         WHERE PH.OrderKey = @c_OrderKey
         AND   PLTD.StorerKey = @c_StorerKey
         AND   EXISTS (  SELECT 1
                         FROM PackDetail AS pd2 WITH (NOLOCK)
                         WHERE pd2.PickSlipNo = PH.PickSlipNo AND pd2.CartonNo = PD.CartonNo
                         GROUP BY pd2.CartonNo
                         HAVING COUNT(DISTINCT pd2.SKU) = 1)
         GROUP BY PD.SKU
                , PD.Qty
                , CASE WHEN C.UDF01 = 'P' THEN
                          ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'), '')
                       ELSE 'N/A' END
                , ISNULL(C.UDF01, '')
         UNION ALL
         SELECT 'MULTI'
              , PD.SKU
              , SUM(PD.Qty) / COUNT(DISTINCT PD.CartonNo)
              , 0
              , SUM(PD.Qty)
              , PD.CartonNo
              , CASE WHEN C.UDF01 = 'P' THEN
                        ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'), '')
                     ELSE 'N/A' END
              , ISNULL(C.UDF01, '')
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
         JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo AND PLTD.Sku = PD.SKU
         JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
         JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                            AND C.UDF01 = 'P'
                                            AND C.Code = CON.ContainerType
         WHERE PH.OrderKey = @c_OrderKey
         AND   PLTD.StorerKey = @c_StorerKey
         AND   NOT EXISTS (  SELECT 1
                             FROM PackDetail AS pd2 WITH (NOLOCK)
                             WHERE pd2.PickSlipNo = PH.PickSlipNo AND pd2.CartonNo = PD.CartonNo
                             GROUP BY pd2.CartonNo
                             HAVING COUNT(DISTINCT pd2.SKU) = 1)
         GROUP BY PD.CartonNo
                , PD.SKU
                , PD.Qty
                , CASE WHEN C.UDF01 = 'P' THEN
                          ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'), '')
                       ELSE 'N/A' END
                , ISNULL(C.UDF01, '')
      END
      ELSE IF @c_facility = 'YPCN1'
      BEGIN
         INSERT INTO #TEMP_CTHTYPEDelNote23 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo, Palletkey, CLKUPUDF01)
         SELECT 'SINGLE'
              , PD.SKU
              , SUM(PD.Qty) / COUNT(DISTINCT PD.CartonNo)
              , COUNT(DISTINCT PD.CartonNo)
              , SUM(PD.Qty)
              , 0
              , 'N/A'
              , ''
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
         WHERE PH.OrderKey = @c_OrderKey
         AND   EXISTS (  SELECT 1
                         FROM PackDetail AS pd2 WITH (NOLOCK)
                         WHERE pd2.PickSlipNo = PH.PickSlipNo AND pd2.CartonNo = PD.CartonNo
                         GROUP BY pd2.CartonNo
                         HAVING COUNT(DISTINCT pd2.SKU) = 1)
         GROUP BY PD.SKU
                , PD.Qty
         UNION ALL
         SELECT 'MULTI'
              , PD.SKU
              , SUM(PD.Qty) / COUNT(DISTINCT PD.CartonNo)
              , 0
              , SUM(PD.Qty)
              , PD.CartonNo
              , 'N/A'
              , ''
         FROM PackHeader PH WITH (NOLOCK)
         JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
         WHERE PH.OrderKey = @c_OrderKey
         AND   NOT EXISTS (  SELECT 1
                             FROM PackDetail AS pd2 WITH (NOLOCK)
                             WHERE pd2.PickSlipNo = PH.PickSlipNo AND pd2.CartonNo = PD.CartonNo
                             GROUP BY pd2.CartonNo
                             HAVING COUNT(DISTINCT pd2.SKU) = 1)
         GROUP BY PD.CartonNo
                , PD.SKU
                , PD.Qty
      END

      DECLARE CS_SinglePack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CartonType
           , SKU
           , QTY
           , CASE WHEN CartonType = 'SINGLE' THEN TotalCtn
                  ELSE CartonNo END
           , TotalQty
           , Palletkey
           , CLKUPUDF01
      FROM #TEMP_CTHTYPEDelNote23
      ORDER BY CartonType DESC
             , CartonNo

      OPEN CS_SinglePack
      FETCH NEXT FROM CS_SinglePack
      INTO @c_CartonType
         , @c_sku
         , @n_CtnQty
         , @n_CtnCount
         , @n_PQty
         , @c_GetPalletKey
         , @C_CLKUPUDF01
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @c_CartonType = 'MULTI'
         BEGIN
            IF @n_CtnCount <> @n_PrevCtnQty
            BEGIN
               SET @n_NoOfCarton = 1
            END
            ELSE
               SET @n_NoOfCarton = 0

            SET @n_PrevCtnQty = @n_CtnCount
         END
         ELSE
            SET @n_NoOfCarton = @n_CtnCount

         SELECT @c_Descr = s.DESCR
              , @n_PGrossWgt = p.GrossWgt
              , @n_PCubeUom3 = p.CubeUOM3
              , @c_PNetWgt = p.NetWgt
              , @c_PCubeUom1 = p.CubeUOM1
              , @n_CaseCnt = p.CaseCnt
              , @c_MSKU = s.MANUFACTURERSKU
         FROM SKU AS s WITH (NOLOCK)
         JOIN PACK AS p WITH (NOLOCK) ON p.PackKey = s.PACKKey
         WHERE s.StorerKey = @c_StorerKey AND s.Sku = @c_sku

         SET @n_PieceQty = 0
         SET @n_PieceQty = @n_PQty % @n_CaseCnt
         IF @n_PQty >= @n_CaseCnt
            SET @n_NoFullCarton = FLOOR(@n_PQty / @n_CaseCnt)
         ELSE
            SET @n_NoFullCarton = 0


         SET @n_CBM = ((@n_PieceQty * @n_PCubeUom3) / 1000000) + ((@n_NoFullCarton * @c_PCubeUom1) / 1000000)
         SET @n_TTLWGT = ((@c_PNetWgt * @n_NoFullCarton) + (@n_PGrossWgt * @n_PieceQty))


         IF @n_CBM < 0.01
            SET @n_CBM = 0.01

         SELECT TOP 1 @c_UnitPrice = CONVERT(DECIMAL(10, 2), o.UnitPrice)
                    , @c_ODUDEF05 = ISNULL(o.UserDefine05, '')
         FROM ORDERDETAIL AS o WITH (NOLOCK)
         WHERE o.OrderKey = @c_OrderKey AND o.Sku = @c_sku

         SET @c_modelno = N''

         SELECT @c_modelno = ISNULL(SkuInfo.ExtendedField05, '')
         FROM SKU WITH (NOLOCK)
         INNER JOIN SkuInfo WITH (NOLOCK) ON (SkuInfo.Storerkey = SKU.StorerKey AND SKU.Sku = SkuInfo.Sku)
         WHERE SKU.StorerKey = @c_StorerKey AND SKU.Sku = @c_sku

         SET @n_TTLPLT = 0
         SET @c_UDF01 = N''

         IF @c_PreOrderKey <> @c_OrderKey
         BEGIN

            IF @n_lineNo = 1
            BEGIN
               SELECT @n_TTLPLT = CASE WHEN C.UDF01 = 'P' THEN COUNT(DISTINCT CD.PalletKey)
                                       ELSE 0 END
               FROM CONTAINERDETAIL CD WITH (NOLOCK)
               JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = @c_MBOLKey
               JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                             AND C.UDF01 = 'P'
                                             AND C.Code = CON.ContainerType
               GROUP BY C.UDF01
            END

            SELECT @c_UDF01 = C.UDF01
            FROM PackHeader PH WITH (NOLOCK)
            JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo
            JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
            JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                               AND C.UDF01 = 'P'
                                               AND C.Code = CON.ContainerType
            WHERE PH.OrderKey = @c_OrderKey
            GROUP BY C.UDF01

            SET @n_EPWGT_Value = 0.00
            SET @n_EPCBM_Value = 0.00

            IF @c_facility IN ( 'WGQAP', 'YPCN1', 'WGQBL', 'WGQUS' )
            BEGIN

               SELECT @n_EPWGT_Value = CASE WHEN ISNUMERIC(C.UDF02) = 1 THEN
                                               ISNULL(CAST(C.UDF02 AS DECIMAL(6, 2)), 0.00)
                                            ELSE 0.00 END
               FROM CODELKUP C (NOLOCK)
               WHERE C.LISTNAME = 'LOGILOC' AND C.Code = @c_facility

            END
            ELSE
            BEGIN
               SELECT @n_EPWGT_Value = CASE WHEN ISNUMERIC(CON.Carrieragent) = 1 THEN
                                               ISNULL(CAST(CON.Carrieragent AS DECIMAL(6, 2)), 0.00)
                                            ELSE 0.00 END
               FROM PackHeader PH WITH (NOLOCK)
               JOIN PackDetail AS PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
               JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PH.OrderKey
               JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.CaseId = PD.LabelNo
               JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
               JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
               JOIN CODELKUP C WITH (NOLOCK) ON  C.LISTNAME = 'CONTAINERT'
                                             AND C.UDF01 = 'P'
                                             AND C.Code = CON.ContainerType
               WHERE PH.OrderKey = @c_OrderKey AND PLTD.StorerKey = @c_StorerKey
            END


            IF @c_UDF01 = 'P'
            BEGIN
               SELECT @n_EPCBM_Value = CASE WHEN ISNUMERIC(C.UDF03) = 1 THEN
                                               ISNULL(CAST(C.UDF03 AS DECIMAL(6, 2)), 0.00)
                                            ELSE 0.00 END
               FROM CODELKUP C (NOLOCK)
               WHERE C.LISTNAME = 'LOGILOC' AND C.Code = @c_facility
            END

         END


         INSERT INTO #TEMP_DelNote59 (
            -- Rowid -- this column value is auto-generated
            MBOLKey, pmtterm, ExtPOKey, OHUdf05, MBOLKeyBarcode, ExternOrdKey, IDS_Company, IDS_Address1, IDS_Address2
          , IDS_Address3, IDS_Address4, IDS_Phone1, IDS_City, BILLTO_Company, BILLTO_Address1, BILLTO_Address2
          , BILLTO_Address3, BILLTO_Address4, BILLTO_City, ShipTO_Company, ShipTO_Address1, ShipTO_Address2
          , ShipTO_Address3, ShipTO_Address4, ShipTO_City, ShipTO_Phone1, ShipTO_Contact1, ShipTO_Country, From_Country
          , StorerKey, SKU, Descr, QtyShipped, UnitPrice, ShipMode, SONo, PCaseCnt --36
          , Pqty, PGrossWgt, PCubeUom1, PalletKey, CTNCOUNT --41
          , PieceQty, TTLWGT, CBM, PCubeUom3, PNetWgt, TTLPLT, ORDGRP, EPWGT, EPCBM, CLKUPUDF01, Orderkey, lott11
          , OrderKey_Inv, ODUDEF05, MSKU, FDESCR, FADD01, FADD02, FADD03, FADD04, FCity, Modelno, Notes2 --WL01
         )
         VALUES (@c_MBOLKey, @c_pmtterm, @c_ExtPOKey, @c_OHUdf05, @c_MBOLKeyBarcode, @c_ExternOrdKey, @c_IDS_Company
               , @c_IDS_Address1, @c_IDS_Address2, @c_IDS_Address3, @c_IDS_Address4, @c_IDS_Phone1, @c_IDS_City
               , @c_BILLTO_Company, @c_BILLTO_Address1, @c_BILLTO_Address2, @c_BILLTO_Address3, @c_BILLTO_Address4
               , @c_BILLTO_City, @c_ShipTO_Company, @c_ShipTO_Address1, @c_ShipTO_Address2, @c_ShipTO_Address3
               , @c_ShipTO_Address4, @c_ShipTO_City, @c_ShipTO_Phone1, @c_ShipTO_Contact1, @c_ShipTO_Country
               , @c_From_Country, @c_StorerKey, @c_sku, @c_Descr, @n_PQty, @c_UnitPrice, @c_ShipMode, @c_SONo
               , @n_CtnQty --36
               , @n_PQty --37
               , @n_PGrossWgt, @c_PCubeUom1, @c_GetPalletKey, @n_NoOfCarton --41
               , @n_PieceQty, @n_TTLWGT, @n_CBM, @n_PCubeUom3, @c_PNetWgt, @n_TTLPLT, @c_OrdGrp, @n_EPWGT_Value
               , @n_EPCBM_Value, @C_CLKUPUDF01, @c_OrderKey, '', @c_OrderKey_Inv, @c_ODUDEF05, @c_MSKU, @c_FDESCR
               , @c_FADD01, @c_FADD02, @c_FADD03, @c_FADD04, @c_FCity, @c_modelno, @c_Notes2 --WL01            
            )

         SET @c_PreOrderKey = @c_OrderKey
         SET @n_lineNo = @n_lineNo + 1


         DELETE #TEMP_CTHTYPEDelNote23

         FETCH NEXT FROM CS_SinglePack
         INTO @c_CartonType
            , @c_sku
            , @n_CtnQty
            , @n_CtnCount
            , @n_PQty
            , @c_GetPalletKey
            , @C_CLKUPUDF01
      END
      CLOSE CS_SinglePack
      DEALLOCATE CS_SinglePack

      FETCH FROM CS_ORDERS_INFO
      INTO @c_OrderKey
         , @c_MBOLKey
         , @c_pmtterm
         , @c_ExtPOKey
         , @c_OHUdf05
         , @c_MBOLKeyBarcode
         , @c_ExternOrdKey
         , @c_IDS_Company
         , @c_IDS_Address1
         , @c_IDS_Address2
         , @c_IDS_Address3
         , @c_IDS_Address4
         , @c_IDS_Phone1
         , @c_IDS_City
         , @c_BILLTO_Company
         , @c_BILLTO_Address1
         , @c_BILLTO_Address2
         , @c_BILLTO_Address3
         , @c_BILLTO_Address4
         , @c_BILLTO_City
         , @c_ShipTO_Company
         , @c_ShipTO_Address1
         , @c_ShipTO_Address2
         , @c_ShipTO_Address3
         , @c_ShipTO_Address4
         , @c_ShipTO_City
         , @c_ShipTO_Phone1
         , @c_ShipTO_Contact1
         , @c_ShipTO_Country
         , @c_From_Country
         , @c_StorerKey
         , @c_ShipMode
         , @c_SONo
         , @c_PalletKey
         , @c_facility
         , @c_OrdGrp
         , @c_OrderKey_Inv
         , @c_FDESCR
         , @c_FADD01
         , @c_FADD02
         , @c_FADD03
         , @c_FADD04
         , @c_FCity
         , @c_Notes2 --WL01                                           

   END

   CLOSE CS_ORDERS_INFO
   DEALLOCATE CS_ORDERS_INFO

   DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBOLKey
                 , Orderkey
                 , SKU
   FROM #TEMP_DelNote59
   WHERE MBOLKey = @c_MBOLKey AND ShipTO_Country = 'TH'

   OPEN TH_ORDERS

   FETCH FROM TH_ORDERS
   INTO @c_Getmbolkey
      , @c_GetOrderKey
      , @c_getsku


   WHILE @@FETCH_STATUS = 0
   BEGIN
      INSERT INTO #TEMP_madein23 (MBOLKey, OrderKey, SKU, lot11, C_Company)
      SELECT DISTINCT ORD.MBOLKey
                    , ORD.OrderKey
                    , PD.Sku
                    , C.Description
                    , ORD.C_Company
      FROM PICKDETAIL PD (NOLOCK)
      JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = PD.OrderKey
      JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON  PLTD.UserDefine02 = PD.OrderKey
                                           AND PLTD.Sku = PD.Sku
                                           AND PLTD.StorerKey = ORD.StorerKey
      JOIN CONTAINERDETAIL CD WITH (NOLOCK) ON CD.PalletKey = PLTD.PalletKey
      JOIN CONTAINER CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey = ORD.MBOLKey
      JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (   LOTT.Sku = PD.Sku
                                              AND LOTT.StorerKey = PD.Storerkey
                                              AND LOTT.Lot = PD.Lot)
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'CTYCAT' AND C.Code = LOTT.Lottable11
      WHERE ORD.MBOLKey = @c_Getmbolkey AND ORD.OrderKey = @c_GetOrderKey AND PD.Sku = @c_getsku

      FETCH FROM TH_ORDERS
      INTO @c_Getmbolkey
         , @c_GetOrderKey
         , @c_getsku
   END

   CLOSE TH_ORDERS
   DEALLOCATE TH_ORDERS

   --SELECT * FROM #TEMP_madein37
   SET @n_CntRec = 0
   SET @c_madein = N''

   IF EXISTS (  SELECT 1
                FROM #TEMP_madein23
                WHERE MBOLKey = @c_MBOLKey)
   BEGIN
      SET @c_UPDATECCOM = N'Y'
   END

   SELECT @n_CntRec = COUNT(DISTINCT lot11)
        , @C_Lottable11 = MIN(lot11)
        , @c_company = MIN(C_Company)
   FROM #TEMP_madein23
   WHERE MBOLKey = @c_MBOLKey

   IF @n_CntRec = 1
   BEGIN
      SET @c_madein = @C_Lottable11
   END
   ELSE
   BEGIN
      DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT lot11
      FROM #TEMP_madein23
      WHERE MBOLKey = @c_MBOLKey


      OPEN MadeIn_loop

      FETCH FROM MadeIn_loop
      INTO @c_lott11
      WHILE @@FETCH_STATUS = 0
      BEGIN

         IF @n_CntRec >= 2
         BEGIN
            SET @c_madein = @c_lott11 + @c_delimiter
         END
         ELSE
         BEGIN
            SET @c_madein = @c_madein + @c_lott11
         END

         SET @n_CntRec = @n_CntRec - 1


         FETCH FROM MadeIn_loop
         INTO @c_lott11
      END

      CLOSE MadeIn_loop
      DEALLOCATE MadeIn_loop
   END

   IF @c_UPDATECCOM = 'Y'
   BEGIN
      UPDATE #TEMP_DelNote59
      SET lott11 = @c_madein
        , ShipTO_Company = @c_company
      WHERE MBOLKey = @c_MBOLKey
   END

   DELETE FROM #TEMP_madein23

   SELECT @c_CLKUDF01 = CLK.UDF01
        , @c_CLKUDF02 = CLK.UDF02
   FROM CODELKUP CLK (NOLOCK)
   WHERE LISTNAME = 'LOGTHSHIP' AND Storerkey = @c_StorerKey


   SELECT Rowid
        , MBOLKey
        , pmtterm
        , ExtPOKey
        , OHUdf05
        , MBOLKeyBarcode
        , ExternOrdKey
        , IDS_Company
        , IDS_Address1
        , IDS_Address2
        , IDS_Address3
        , IDS_Address4
        , IDS_Phone1
        , IDS_City
        , BILLTO_Company
        , BILLTO_Address1
        , BILLTO_Address2
        , BILLTO_Address3
        , BILLTO_Address4
        , BILLTO_City
        , ShipTO_Company
        , ShipTO_Address1
        , ShipTO_Address2
        , ShipTO_Address3
        , ShipTO_Address4
        , ShipTO_City
        , ShipTO_Phone1
        , ShipTO_Contact1
        , ShipTO_Country
        , From_Country
        , StorerKey
        , SKU
        , Descr
        , QtyShipped
        , UnitPrice
        , ShipMode
        , SONo
        , PCaseCnt
        , Pqty
        , PGrossWgt
        , PCubeUom1
        , PalletKey
        --, ODUDEF05
        , CTNCOUNT
        , PieceQty
        , ROUND(TTLWGT, 2) AS TTLWGT
        , ROUND(CBM, 2) AS CBM
        , PCubeUom3
        , PNetWgt
        , TTLPLT
        , ORDGRP
        , EPWGT
        , EPCBM
        , CLKUPUDF01
        , lott11
        , OrderKey_Inv
        , ShipType = @c_ShipType
        , InvoiceNo = CASE WHEN OrderKey_Inv = '' THEN MBOLKey
                           ELSE 'A' + RTRIM(OrderKey_Inv)END
        , CLKUDF01 = ISNULL(@c_CLKUDF01, '')
        , CLKUDF02 = ISNULL(@c_CLKUDF02, '')
        , ODUDEF05
        , MSKU
        , FDESCR
        , FADD01
        , FADD02
        , FADD03
        , FADD04
        , FCity
        , Modelno
        , Notes2 --WL01
   FROM #TEMP_DelNote59
   ORDER BY MBOLKey
          , ExternOrdKey
          , Rowid
          , SKU
          , CTNCOUNT DESC


END


GO