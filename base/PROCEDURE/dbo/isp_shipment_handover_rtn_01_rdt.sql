SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_Shipment_Handover_RTN_01_rdt                    */  
/* Creation Date: 2021-08-12                                             */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-17462 - UA pre Delivery RDT1847 Return handover Report   */  
/*                                                                       */  
/* Called By: r_shipment_handover_rtn_01_rdt                             */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author  Ver   Purposes                                    */  
/*************************************************************************/  
CREATE PROC [dbo].[isp_Shipment_Handover_RTN_01_rdt] (
   @c_RTNPalletID   NVARCHAR(100) 
)    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_CountOrders INT = 0
         , @c_EditWho     NVARCHAR(100) = ''
  
   SELECT @n_CountOrders = COUNT(DISTINCT TPI.Orderkey)
        , @c_EditWho     = MAX(TPI.EditWho)
   FROM rdt.rdtTruckPackInfo TPI (NOLOCK) 
   WHERE TPI.ReturnPalletID = @c_RTNPalletID 
   AND TPI.IsReturn = 'Y'

   SELECT DISTINCT TPI.TrackingNo
                 , TPI.Orderkey
                 , @n_CountOrders AS CountOrders
                 , @c_RTNPalletID AS RTNPalletID
                 , @c_EditWho     AS EditWho
   FROM rdt.rdtTruckPackInfo TPI (NOLOCK)  
   WHERE TPI.ReturnPalletID = @c_RTNPalletID 
   AND TPI.IsReturn = 'Y'

QUIT_SP:  
END

GO