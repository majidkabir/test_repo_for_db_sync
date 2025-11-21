SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE VIEW [dbo].[V_OWPICK]  
AS  
SELECT O.ExternOrderkey, O.Orderkey, O.Facility, O.Consigneekey, Date = MAX(OD.Editdate)  
FROM  dbo.Orders O (nolock)   
INNER JOIN dbo.Orderdetail OD (NOLOCK) ON O.Orderkey = OD.Orderkey  
INNER JOIN dbo.StorerConfig S (NOLOCK) ON S.Storerkey = O.Storerkey AND S.Configkey = 'OWITF' AND S.svalue = '1'  
GROUP BY O.ExternOrderkey, O.Orderkey, O.Facility, O.Consigneekey   
HAVING SUM(OD.QtyPicked) > 0   
  
GO