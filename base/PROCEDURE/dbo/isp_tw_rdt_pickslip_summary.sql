SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_tw_rdt_pickslip_summary                             */  
/* Creation Date: 21-Apr-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Mingle                                                   */  
/*                                                                      */  
/* Purpose:  WMS-19387                                                  */  
/*        :                                                             */  
/* Called By: r_tw_rdt_pickslip_summary                                 */  
/*          :                                                           */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver Purposes                                  */  
/* 21-APR-2022  MINGLE    1.0 Created.(Devops Scripts Combine )         */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_tw_rdt_pickslip_summary] (    
   @c_Storerkey NVARCHAR(10) = ''  
  ,@c_Loadkey NVARCHAR(15) = ''  
  ,@c_DateFM NVARCHAR(20) = ''   
  ,@c_DateTo NVARCHAR(20) = ''   
  ,@c_Orderby NVARCHAR(20) = ''   
  ,@c_SQL NVARCHAR(MAX) = ''  
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   --SET QUOTED_IDENTIFIER OFF    
   --SET ANSI_NULLS OFF    
   --SET ANSI_DEFAULTS OFF   
     
   --DECLARE @c_SQL NVARCHAR(MAX)  
  
   SET @c_SQL = ' SELECT '   
+ '  AL4.Company, '  
+ '  AL2.LoadKey, '  
+ '  AL1.C_Company, '  
+ '  AL1.ExternOrderKey,  '  
+ ' SUM(AL5.Qty) AS QTY,  '  
+ ' CONVERT(VARCHAR,AL1.DeliveryDate,111) AS DeliveryDate, '  
+ ' dbo.fn_Encode_IDA_Code128(RTRIM(AL7.PickHeaderKey)) AS PickSlipNoBarcode, '  
+ ' AL7.PickHeaderKey AS PickSlipNo '  
+ ' FROM dbo.V_ORDERS AL1 (NOLOCK) '  
+ ' INNER JOIN dbo.V_LoadPlanDetail AL3  (NOLOCK) ON AL1.OrderKey = AL3.OrderKey '  
+ ' INNER JOIN dbo.V_LoadPlan AL2  (NOLOCK) ON AL3.LoadKey = AL2.LoadKey '  
+ ' INNER JOIN dbo.V_STORER AL4  (NOLOCK) ON AL4.StorerKey=AL1.StorerKey  AND AL4.type= ''1'''  
+ ' INNER JOIN dbo.V_PICKDETAIL AL5  (NOLOCK) ON AL5.OrderKey = AL1.OrderKey AND AL5.Storerkey = AL1.StorerKey  '  
+ ' INNER JOIN dbo.V_LOTATTRIBUTE AL6  (NOLOCK) ON AL6.StorerKey = AL5.Storerkey AND AL6.Lot = AL5.Lot '  
+ ' INNER JOIN dbo.V_PICKHEADER AL7 (NOLOCK) ON AL1.OrderKey=AL7.OrderKey '  
+ ' WHERE AL1.StorerKey = ''' +  @c_Storerkey  +''''  
+ ' AND AL1.Loadkey = Case When ISNULL( ''' + @c_Loadkey  + ''' ,'''') <> '''' Then ''' +  @c_Loadkey +''' Else AL1.Loadkey End '  
+ ' AND CONVERT(datetime, CONVERT(CHAR(10), AL1.DeliveryDate ,120)) BETWEEN ''' + @c_DateFM + ''' AND ''' + @c_DateTo + ''''  
+ ' GROUP BY AL4.Company,AL2.LoadKey, AL1.C_Company, AL1.ExternOrderKey, CONVERT(VARCHAR,AL1.DeliveryDate,111),AL7.PickHeaderKey '  
--+ ' ORDER BY AL2.LoadKey,AL1.ExternOrderKey '  
  
IF ISNULL(@c_Orderby,'') <> ''   
 SET @c_SQL = @c_SQL + ' ORDER BY ' + @c_Orderby  
ELSE   
 SET @c_SQL = @c_SQL + ' ORDER BY AL2.LoadKey,AL1.ExternOrderKey '  
  
EXEC SP_EXECUTESQL  @c_SQL  
  
END -- procedure  

GO