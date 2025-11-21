SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE VIEW [dbo].[V_OWSHIP]  
AS  
SELECT O.ExternOrderkey, O.Orderkey, O.Facility, O.Consigneekey, Date = MAX(OD.Editdate)  
FROM  dbo.Orders O (nolock)   
INNER JOIN dbo.StorerConfig S (NOLOCK) ON S.Storerkey = O.Storerkey AND S.Configkey = 'OWITF' AND S.svalue = '1'  
INNER JOIN dbo.Orderdetail OD (nolock) ON O.Orderkey = OD.Orderkey AND S.Storerkey = OD.Storerkey  
GROUP BY O.ExternOrderkey, O.Orderkey, O.Facility, O.Consigneekey   
HAVING SUM(OD.ShippedQty) > 0  
  
GO