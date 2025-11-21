SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [BI].[V_TH_MATA_FG_shipped_daily] AS
SELECT
   O.Facility,
   O.ExternOrderKey,
   O.MBOLKey,
   O.Status AS 'Status',
   case
      when
         O.Facility = 'IND'
      then
         'Industrail'
      else
         'Commercial'
   end AS 'Prod_Type'
, O.ConsigneeKey AS 'Customer_Code', O.C_Address1 AS 'Delivery_Address', A.Lottable02 AS 'Serail No.', OD.Sku AS 'CAI', S.DESCR AS 'Size', S.SKUGROUP, Replace(
   case
      when
         PATINDEX('%/%', A.Lottable03) <> 0
         or LEN (A.Lottable03) < 10
      then
         substring(A.Lottable03, 1, 2)
      else
         substring(A.Lottable03, 1, 1)
   end
, '/', '') AS  'R_Level',
   case
      when
         (
            Replace(
            case
               when
                  PATINDEX('%/%', A.Lottable03) <> 0
                  or LEN (A.Lottable03) < 10
               then
                  substring(A.Lottable03, 1, 2)
               else
                  substring(A.Lottable03, 1, 1)
            end
, '/', '')
         )
         = '0'
      then
         'N'
      else
         'R'
   end AS 'N-New'
, M.CustCnt, A.Lottable01 AS 'Airline',
   case
      when
         charindex('/', A.Lottable01) = 0
      then
         A.Lottable01
      else
         substring(A.Lottable01, charindex('/', A.Lottable01) + 1, 3)
   end AS 'Customer'
, A.Lottable09 AS 'RO/PO Number', M.VoyageNumber AS 'Container No.', M.OtherReference AS 'Seal_No', M.PlaceOfLoadingQualifier AS 'Port of Loading', M.PlaceOfdischargeQualifier AS 'Port of Dischange', M.EditDate AS 'Loading Date', A.Lottable12 AS 'WH-Facility', 1 AS 'Qty', S.BUSR6 AS 'Type'
FROM
   dbo.ORDERS O with (nolock)
JOIN dbo.ORDERDETAIL OD with (nolock) ON O.OrderKey = OD.OrderKey
      AND O.StorerKey = OD.StorerKey
JOIN dbo.PICKDETAIL PD with (nolock) ON OD.OrderLineNumber = PD.OrderLineNumber
      AND OD.OrderKey = PD.OrderKey
JOIN dbo.MBOL M with (nolock) ON O.MBOLKey = M.MbolKey
JOIN dbo.SKU S with (nolock) ON OD.Sku = S.Sku
JOIN dbo.LOTATTRIBUTE A with (nolock) ON PD.Lot = A.Lot
      AND PD.Sku = A.Sku
      AND PD.Storerkey = A.StorerKey
WHERE
   (
(O.EditDate >= convert(varchar(10), getdate() - 1, 120)
      and O.EditDate < convert(varchar(10), getdate(), 120)
      AND O.Facility IN
      (
         'IND', 'MCNKA', 'MCNKF'
      )
      AND S.StorerKey = 'MATA'
      AND O.StorerKey = 'MATA'
      AND O.Status >= '0')
   )

GO