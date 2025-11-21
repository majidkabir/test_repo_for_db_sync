SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_OWOrdStatus]  
AS  
SELECT O.ExternOrderkey, O.Orderkey, O.Facility, CASE O.Status WHEN '9' THEN 'Shipped'   
                     WHEN '5' THEN 'Picked'   
                     WHEN '3' THEN 'Pick In Progress'   
                     WHEN '2' THEN 'Allocated'   
                      WHEN 'CANC' THEN 'Cancelled'  
                     ELSE 'Normal' END As Status  
FROM  dbo.Orders O (nolock)   
INNER JOIN dbo.Orderdetail OD (nolock) ON O.Orderkey = OD.Orderkey  
INNER JOIN dbo.StorerConfig S (NOLOCK) ON S.Storerkey = O.Storerkey AND S.Configkey = 'OWITF' AND S.svalue = '1'  
  
GO