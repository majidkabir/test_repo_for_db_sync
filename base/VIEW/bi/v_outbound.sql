SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

--https://jira.lfapps.net/browse/BI-43
CREATE   VIEW  [BI].[V_OUTBOUND] as
SELECT O.ADDDATE
, O.EDITDATE
, O.StorerKey
, O.FACILITY
, O.ExternOrderKey
, O.DeliveryDate
, O.Priority
, O.C_Company
, O.C_Zip
, O.C_Country
, OD.ExternLineNo
, OD.Sku
, S.DESCR
, S.STYLE
, S.COLOR
, S.SIZE
, S.ITEMCLASS
, OD.OpenQty
, O.DOCTYPE
, OD.QtyAllocated
, OD.QtyPicked
, OD.ShippedQty
, OD.UOM
, OD.Lottable01
, OD.Lottable02
, OD.Lottable03
, O.OrderKey
, O.C_Contact1
, OD.OriginalQty
, S.Notes1
, O.UserDefine04
, O.Status
, O.Type
, O.UserDefine06
, O.BuyerPO
, O.BillToKey
, O.C_City
, O.C_Address1
, O.C_Phone1
, S.STDGROSSWGT
, S.STDCUBE
, O.Consigneekey --https://jira.lfapps.net/browse/WMS-10449
, O.Userdefine02
, O.Salesman
, O.Ordergroup
, S.BUSR9
, O.C_State
, B.StorerKey AS BStorerKey  --https://jiralfl.atlassian.net/browse/BI-49
, B.Type AS BType
, B.Company AS BCompany
, B.Address1 AS BAddress1
, P.CaseCnt --https://jiralfl.atlassian.net/browse/BI-49
FROM      ORDERS      AS O   WITH (NOLOCK)
LEFT JOIN ORDERDETAIL AS OD  WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.StorerKey = O.StorerKey
LEFT JOIN SKU         AS S   WITH (NOLOCK) ON S.Sku = OD.Sku  AND S.StorerKey = O.StorerKey
JOIN      Pack        AS P   WITH (NOLOCK) ON P.PackKey = S.PACKKey
LEFT JOIN STORER      AS B   WITH (NOLOCK) ON B.StorerKey = O.BillToKey
WHERE O.ADDDATE>DATEADD(month,-3,GETDATE())

GO