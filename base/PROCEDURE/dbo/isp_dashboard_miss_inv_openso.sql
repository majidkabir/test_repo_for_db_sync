SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Dashboard_Miss_Inv_OpenSO                           */
/* Creation Date: 17-NOV-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3281 - HnM India WMS Dashboard for Orders with Missing  */
/*        : Invoices                                                    */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_Dashboard_Miss_Inv_OpenSO]
           @c_Facility           NVARCHAR(30)
         , @c_Storerkey          NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @d_Now             DATETIME

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @d_Now = GETDATE()

   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 2
         ,WaitHourDesc= '< 1 hour'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '0'
         ,SOStatus    = 'PENDING'
         ,AddDate_Min = ISNULL(MIN(OH.AddDate), '1900-01-01')
         ,AddDate_Max = ISNULL(MAX(OH.AddDate), '1900-01-01') 
 
         ,'    ' rowfocusindicatorcol    
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDING'
   AND   OH.Status = '0'
   AND   DATEDIFF(HOUR, OH.AddDate, @d_Now) < 1
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 3
         ,WaitHourDesc= '>= 1 AND < 2 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '0'
         ,SOStatus    = 'PENDING'
         ,AddDate_Min = ISNULL(MIN(OH.AddDate), '1900-01-01')
         ,AddDate_Max = ISNULL(MAX(OH.AddDate), '1900-01-01')  
         ,'    ' rowfocusindicatorcol   
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDING'
   AND   OH.Status = '0'
   AND   DATEDIFF(HOUR, OH.AddDate, @d_Now) >= 1 
   AND   DATEDIFF(HOUR, OH.AddDate, @d_Now) <  2
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 4 
         ,WaitHourDesc= '>= 2 AND < 3 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '0'
         ,SOStatus    = 'PENDING'
         ,AddDate_Min = ISNULL(MIN(OH.AddDate), '1900-01-01')
         ,AddDate_Max = ISNULL(MAX(OH.AddDate), '1900-01-01')  
         ,'    ' rowfocusindicatorcol    
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDING'
   AND   OH.Status = '0'
   AND  DATEDIFF(HOUR, OH.AddDate, @d_Now) >= 2 
   AND  DATEDIFF(HOUR, OH.AddDate, @d_Now) <  3
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 1
         ,WaitHourDesc= '>= 3 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '0'
         ,SOStatus    = 'PENDING'
         ,AddDate_Min = ISNULL(MIN(OH.AddDate), '1900-01-01')
         ,AddDate_Max = ISNULL(MAX(OH.AddDate), '1900-01-01')  
         ,'    ' rowfocusindicatorcol   
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDING'
   AND   OH.Status = '0'
   AND   DATEDIFF(HOUR, OH.AddDate, @d_Now) >= 3 
   ORDER BY WaitHourRow

QUIT_SP:

END -- procedure

GO