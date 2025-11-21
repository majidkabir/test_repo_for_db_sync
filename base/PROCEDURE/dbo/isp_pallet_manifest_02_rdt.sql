SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Pallet_Manifest_02_rdt                         */  
/* Creation Date: 02-Aug-2022                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-20346 - CN LOREAL RDT Pallet List Report Printing       */  
/*                                                                      */  
/* Called By: r_dw_pallet_manifest_02_rdt                               */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 02-Aug-2022  WLChooi   1.0   DevOps Combine Script                   */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_Pallet_Manifest_02_rdt]  
      @c_ID       NVARCHAR(50)
    , @c_ToLoc    NVARCHAR(20) = ''
    , @n_Qty      INT = 0
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue        INT,  
           @n_cnt             INT,  
           @n_starttcnt       INT,
           @c_Orderkey        NVARCHAR(10)

   SELECT @n_Continue = 1, @n_starttcnt = @@TRANCOUNT

   SELECT DISTINCT 
          LLI.ID
        , TRIM(OD.SKU) AS SKU
        , TRIM(S.DESCR) AS DESCR 
        , OD.OriginalQty AS OriginalQty 
        , @c_ToLoc AS ToLoc 
        , CONVERT(NVARCHAR(10), GETDATE(), 111) AS TodayDate 
        , @n_Qty AS Qty
   FROM LOTXLOCXID LLI (NOLOCK) 
   CROSS APPLY (SELECT TOP 1 ORDERS.Orderkey
                FROM ORDERS (NOLOCK) 
                WHERE ORDERS.Notes2 = LLI.ID 
                AND ORDERS.StorerKey = LLI.StorerKey ) AS OH
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey 
                               AND LLI.StorerKey = OD.StorerKey 
                               AND LLI.SKU = OD.SKU 
   JOIN SKU S (NOLOCK) ON OD.StorerKey = S.StorerKey 
                      AND OD.SKU = S.SKU 
   WHERE LLI.Id = @c_ID
   --AND OH.[Status] <> ''9''

QUIT_SP:     
END

GO