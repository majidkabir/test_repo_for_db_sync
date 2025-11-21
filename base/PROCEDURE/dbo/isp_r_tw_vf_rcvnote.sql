SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_r_tw_vf_rcvnote_01                             */
/* Creation Date:  13-Sep-2018                                          */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Consolidate the receipts and UCCs then generates report     */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version:                                                        */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author     Ver.  Purposes                                */
/* 13/09/2018  Sten Feng  1.0   Initial version.                        */
/* 29-09-2018  Leong      1.1   INC0408690 - Fix PoGroup column unable  */
/*                              to display in PB object.                */
/* 02/10/2018  Sten Feng  1.2   1. Fix PoGroup column to prevent it is  */
/*                                 to short then cause shbstring fails  */
/*                              2. Fix incorrect UCC_Qty                */
/* 31/05/2019  SPChin     1.3   INC0720225 - Bug Fixed                  */
/* 14/01/2020  SPChin     1.4   Remove  PROC  WITH EXECUTE AS 'briorpt' */
/************************************************************************/

CREATE PROC [dbo].[isp_r_tw_vf_rcvnote]
(
   @storerkey VARCHAR(20),
   @containerkey VARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL(OBJECT_ID('tempdb..#VFRcvNote'),'') <> '' -- INC0408690
   BEGIN
      DROP TABLE #VFRcvNote
   END

   CREATE TABLE #VFRcvNote (
        Containerkey        NVARCHAR(18)   NULL
      , ContainerkeyCode    NVARCHAR(100)  NULL
      , Receiptkey          NVARCHAR(10)   NULL
      , ReceiptkeyCode      NVARCHAR(100)  NULL
      , Externreceiptkey    NVARCHAR(20)   NULL
      , Storerkey           NVARCHAR(15)   NULL
      , WarehouseReference  NVARCHAR(18)   NULL
      , VehicleDate         NVARCHAR(18)   NULL
      , Cat                 NVARCHAR(50)   NULL
      , Shipment            NVARCHAR(18)   NULL
      , C_Company           NVARCHAR(450)  NULL
      , Consignee           NVARCHAR(15)   NULL
      , ContainerType       NVARCHAR(20)   NULL
      , Brand               NVARCHAR(30)   NULL
      , Notes               NVARCHAR(4000) NULL
      , PoGroup             NVARCHAR(4000) NULL
      , PoType              NVARCHAR(10)   NULL
      , EffectiveDate       DATETIME       NULL
      , NO#                 NVARCHAR(30)   NULL
      , OBD                 NVARCHAR(20)   NULL
      , Hostwh_Code         NVARCHAR(30)   NULL
      , Cartons             INT            NULL
      , Qty                 INT            NULL
      )

   TRUNCATE TABLE #VFRcvNote

   INSERT INTO #VFRcvNote (
        Containerkey, ContainerkeyCode, Receiptkey, ReceiptkeyCode, Externreceiptkey
      , Storerkey, WarehouseReference, VehicleDate, Cat, Shipment, C_Company, Consignee
      , ContainerType, Brand, Notes, PoGroup, PoType, EffectiveDate, NO#
      , OBD, Hostwh_Code, Cartons, Qty
      )
   SELECT
      Final.Containerkey,
      dbo.fn_Encode_IDA_Code128(RTRIM(Final.Containerkey)) AS ContainerkeyCode,
      Final.Receiptkey,
      dbo.fn_Encode_IDA_Code128(RTRIM(Final.Receiptkey)) AS ReceiptkeyCode,
      Final.Externreceiptkey,
      Final.Storerkey,
      Final.Warehousereference,
      Final.Vehicledate,
      Final.cat,
      Final.Signatory as Shipment,
      Final.C_Company,
      Final.CONSIGNEE,
      Final.Containertype,
      Final.BRAND,
      Final.Notes,
     (CASE CHARINDEX(',', Final.PoGroup)
           WHEN 0 THEN Final.PoGroup
         ELSE
         (CASE WHEN LEN(Final.PoGroup) <= 6 THEN ''
               WHEN LEN(Final.PoGroup) <=20 THEN REPLACE(Final.PoGroup,' , ','')
               ELSE
               SUBSTRING(Final.PoGroup,CHARINDEX(' , ', Final.PoGroup)+3,LEN(Final.PoGroup)-CHARINDEX(' , ', Final.PoGroup)-3)
               END) END) AS PoGroup,
      Final.Potype,
      Final.Effectivedate,
      Final.NO#,
      Final.OBD,
      (CASE
        WHEN Final.WH_TYPE IS NOT NULL THEN
             CAST(LEFT(Final.WH_TYPE,LEN(Final.WH_TYPE)-1) AS VARCHAR(30))
       ELSE ' ' END) AS HOSTWH_CODE,
      COUNT(DISTINCT Final.UCCNo) CARTONS,
      SUM(Final.UCC_QTY) QTY
   FROM
   (
       SELECT
         Containerkey,
         Receiptkey,
         Externreceiptkey,
         Storerkey,
         Warehousereference,
         Vehicledate,
         cat,
         Signatory,
         C_Company,
         CONSIGNEE,
         Containertype,
         BRAND,
         Notes,
         (SELECT DISTINCT PoGroup + ' , '
          FROM V_PO INNER JOIN V_RECEIPTDETAIL ON V_PO.ExternPOKey = V_RECEIPTDETAIL.ExternReceiptKey AND V_PO.STORERKEY = V_RECEIPTDETAIL.STORERKEY
        INNER JOIN V_RECEIPT ON V_RECEIPT.RECEIPTKEY = V_RECEIPTDETAIL.RECEIPTKEY
          WHERE V_RECEIPT.ContainerKey = SV.Containerkey
          AND V_PO.StorerKey = SV.Storerkey
          AND V_PO.PoGroup IS NOT NULL
          FOR XML PATH('')) AS PoGroup,
         POtype,
         Effectivedate,
         NO#,
         OBD,
         SKU,
         UCCNo,
         UCC_QTY,
         (SELECT DISTINCT SUBSTRING(V_RECEIPTDETAIL.Lottable02,1,7) + ' / '
             FROM V_RECEIPTDETAIL
            WHERE V_RECEIPTDETAIL.ReceiptKey = SV.ReceiptKey
            AND V_RECEIPTDETAIL.StorerKey = SV.Storerkey FOR XML PATH('')) AS WH_TYPE
         FROM (
            SELECT RCP.Containerkey,
                  RCP.Receiptkey,
                  RCP.Externreceiptkey,
                  UCC.Uccno,
                  RCP.Storerkey,
                  UCC.Sku,
                  UCC.Sourcekey,
                  RCP.Warehousereference,
                  RCP.Vehicledate,
                  F.cat,
                  RCP.Signatory,
                  F.C_Company,
                  F.CONSIGNEE,
                  RCP.Containertype,
                  D.Busr5 AS BRAND,
                  RCP.Notes,
                  RCP.Qtyexpected,
                  RCP.PoGroup,
                  RCP.POType,
                  RCP.Effectivedate,
                  UCC.Userdefined08 AS NO#,
                  (CASE WHEN RCP.Potype =  'NLCC-X'  THEN ''
                  ELSE RCP.Externreceiptkey END) AS OBD,
                  UCC.UCC_QTY
              FROM (
                  SELECT
                     A.POKEY,
                     A.StorerKey,
                     A.ContainerKey,
                     B.EXTERNPOKEY,
                     A.RECEIPTKEY,
                     A.Warehousereference,
                     A.Vehicledate,
                     A.Signatory,
                     A.Containertype,
                     A.Notes,
                     B.ExternReceiptKey,
                     A.Effectivedate,
                     B.Sku,
                     --B.Lottable02,   Remove for fix incorrect UCC
                     V_PO.POGroup,
                     V_PO.POType,
                  SUM(B.QtyExpected) QtyExpected
                  FROM V_RECEIPT A (NOLOCK) INNER JOIN V_RECEIPTDETAIL B (NOLOCK) ON A.RECEIPTKEY = B.RECEIPTKEY
                  INNER JOIN V_SKU (NOLOCK) ON B.SKU = V_SKU.SKU
                  LEFT JOIN V_PO (NOLOCK) ON V_PO.STORERKEY = A.StorerKey AND V_PO.ExternPOKey = A.externReceiptKey
                  WHERE A.STORERKEY = @storerkey
                  AND A.ContainerKey = @containerkey
                  GROUP BY
                  A.POKEY,
                  A.StorerKey,
                  A.ContainerKey,
                  B.EXTERNPOKEY,
                  A.RECEIPTKEY,
                  A.Warehousereference,
                  A.Vehicledate,
                  A.Signatory,
                  A.Containertype,
                  A.Notes,
                  B.ExternReceiptKey,
                  A.Effectivedate,
                  B.Sku,
                  --B.Lottable02,   Remove for fix incorrect UCC
                  V_PO.POGroup,
                  V_PO.POType
                  ) RCP LEFT JOIN (
                     SELECT
                        V_UCC.UCCNO,
                        V_UCC.STORERKEY,
                        V_UCC.EXTERNKEY,
                        V_UCC.Sourcekey,
                        V_UCC.Sourcetype,
                        V_UCC.UCC_RowRef,
                        V_UCC.Userdefined08,
                        V_UCC.SKU,
                        SUM(V_UCC.QTY) UCC_QTY
                     FROM V_UCC (NOLOCK)
                     WHERE V_UCC.Storerkey = @storerkey
                     GROUP BY
                        V_UCC.UCCNO,
                        V_UCC.STORERKEY,
                        V_UCC.EXTERNKEY,
                        V_UCC.Sourcekey,
                        V_UCC.Sourcetype,
                        V_UCC.UCC_RowRef,
                        V_UCC.Userdefined08,
                   V_UCC.SKU) UCC ON RCP.StorerKey = UCC.Storerkey
                  AND RCP.Sku = UCC.SKU
                  AND RCP.ExternReceiptKey = UCC.ExternKey
                  INNER JOIN V_SKU D (NOLOCK) ON RCP.SKU = D.SKU AND RCP.StorerKey = D.StorerKey
                  LEFT JOIN (
                     SELECT DISTINCT V_Storer.Storerkey AS CONSIGNEE,
                                     V_Storer.Company,
                                     E.OBD#,
                                     E.C_Company,
                                     E.CAT
                     FROM TW_LOCAL.dbo.VF_PackingList E (NOLOCK) LEFT JOIN V_STORER (NOLOCK) ON E.C_Company = V_STORER.Company
                     WHERE V_STORER.CONSIGNEEFOR = @storerkey
                     AND V_STORER.TYPE = '2') F ON RCP.EXTERNRECEIPTKEY = F.OBD#) SV) Final
   GROUP BY Final.Containerkey,
          Final.Receiptkey,
          Final.Externreceiptkey,
          Final.Storerkey,
          Final.Warehousereference,
          Final.Vehicledate,
          Final.cat,
          Final.Signatory,
          Final.C_Company,
          Final.CONSIGNEE,
          Final.Containertype,
          Final.BRAND,
          Final.Notes,
          Final.PoGroup,
          Final.Potype,
          Final.Effectivedate,
          Final.NO#,
          Final.OBD,
          (CASE
             WHEN Final.WH_TYPE IS NOT NULL THEN
             CAST(LEFT(Final.WH_TYPE,LEN(Final.WH_TYPE)-1) AS VARCHAR(30))
         ELSE ' ' END)
   ORDER BY Final.Containerkey,
            Final.Potype,
            Final.NO#,
            Final.Receiptkey

   SELECT
        Containerkey
      , ContainerkeyCode
      , Receiptkey
      , ReceiptkeyCode
      , Externreceiptkey
      , Storerkey
      , WarehouseReference
      , VehicleDate
      , Cat
      , Shipment
      , C_Company
      , Consignee
      , ContainerType
      , Brand
      , Notes
      , PoGroup
      , PoType
      , EffectiveDate
      , NO#
      , OBD
      , Hostwh_Code
      , Cartons
      , Qty
   FROM #VFRcvNote WITH (NOLOCK)
   ORDER BY Containerkey
          , PoType
          , NO#
          , Receiptkey
END

GO