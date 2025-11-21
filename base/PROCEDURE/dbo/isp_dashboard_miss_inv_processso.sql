SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Dashboard_Miss_Inv_ProcessSO                        */
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
CREATE PROC [dbo].[isp_Dashboard_Miss_Inv_ProcessSO]
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
         ,WaitHourDesc= '< 0.5 hour'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '5'
         ,SOStatus    = 'PENDGET'
         ,EditDate_Min = ISNULL(MIN(OH.EditDate), '1900-01-01')
         ,EditDate_Max = ISNULL(MAX(OH.EditDate), '1900-01-01') 
         ,'    ' rowfocusindicatorcol 
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDGET'
   AND   OH.Status   = '5'
   --AND   OH.Status > '0' AND OH.Status < '9'
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) < 30
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 3 
         ,WaitHourDesc= '>= 0.5 AND < 1 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '5'
         ,SOStatus    = 'PENDGET'
         ,EditDate_Min = ISNULL(MIN(OH.EditDate), '1900-01-01')
         ,EditDate_Max = ISNULL(MAX(OH.EditDate), '1900-01-01')
         ,'    ' rowfocusindicatorcol     
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDGET'
   AND   OH.Status   = '5'
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) >= 30 
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) <  60
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 4 
         ,WaitHourDesc= '>= 1 AND < 1.5 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '5'
         ,SOStatus    = 'PENDGET'
         ,EditDate_Min = ISNULL(MIN(OH.EditDate), '1900-01-01')
         ,EditDate_Max = ISNULL(MAX(OH.EditDate), '1900-01-01')
         ,'    ' rowfocusindicatorcol     
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDGET'
   AND   OH.Status   = '5'
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) >= 60 
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) <  90
   UNION ALL
   SELECT Facility  = @c_Facility    
         ,Storerkey = @c_Storerkey
         ,WaitHourRow = 1 
         ,WaitHourDesc= '>= 1.5 hours'
         ,NoOfOrder   = COUNT(DISTINCT OH.Orderkey)
         ,NoOfSku     = COUNT(DISTINCT OD.Sku)
         ,TotalOrderQty   = ISNULL(SUM(OD.OpenQty),0)
         ,TotalProcessQty = ISNULL(SUM(OD.QtyAllocated + OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty),0)
         ,Status      = '5'
         ,SOStatus    = 'PENDGET'
         ,EditDate_Min = ISNULL(MIN(OH.EditDate), '1900-01-01')
         ,EditDate_Max = ISNULL(MAX(OH.EditDate), '1900-01-01') 
         ,'    ' rowfocusindicatorcol     
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE OH.Facility = @c_Facility
   AND   OH.Storerkey= @c_Storerkey
   AND   OH.SOStatus = 'PENDGET'
   AND   OH.Status   = '5'
   AND  DATEDIFF(MINUTE, OH.EditDate, @d_Now) >= 90
   ORDER BY WaitHourRow

QUIT_SP:

END -- procedure

GO