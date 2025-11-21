SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/              
/* Store Procedure: isp_GetDispatchLabel_14                                   */              
/* Creation Date: 05-Oct-2020                                                 */              
/* Copyright: LFL                                                             */              
/* Written by:                                                                */              
/*                                                                            */              
/* Purpose: WMS-15275-[MY] - CMGMY – Exceed despatch label for manual packing */
/*                                                                            */
/*                                                                            */              
/*                                                                            */              
/* Called By: r_dw_dispatch_label14                                           */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */ 
/* 18-Nov-2020  CSCHONG   1.1   WMS-15719 revised field logic (CS01)          */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_GetDispatchLabel_14]             
       ( @c_ORDERNumber    NVARCHAR(10) = '',
        @n_CurrentPage     INT = 1
        )               
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_Continue        INT = 1,
           @c_CarrierKey      NVARCHAR(10) = '',
           @c_Storerkey       NVARCHAR(15) = ''
   
   IF @c_ORDERNumber = NULL SET @c_ORDERNumber = ''
   IF @n_CurrentPage = NULL OR @n_CurrentPage = 0 SET @n_CurrentPage = 1

   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM  ORDERS OH (NOLOCK)
      WHERE OH.Orderkey = @c_ORDERNumber
   END


   IF( @n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT   DISTINCT 
             Orderkey =ORDERS.OrderKey,
             EXTERNORDERKEY = LTRIM(RTRIM(ORDERS.EXTERNORDERKEY)),  
             Storerkey = ORDERS.Storerkey ,
             Consigneekey =ORDERS.ConsigneeKey,   
             ExternPOkey = ORDERS.ExternPOkey,  
             DELDate = ORDERS.DeliveryDate, 
             ST_Company = ST.Company,
             ST_ADD1 = ST.Address1,
             ST_ADD2 = ST.Address2,
             ST_ADD3 = ST.Address3,
             ST_ADD4 = ST.Address4,
             ST_Zip  = LTRIM(RTRIM(ISNULL(ST.Zip,''))), 
             ST_City = LTRIM(RTRIM(ISNULL(ST.city,''))), 
             ST_State = LTRIM(RTRIM(ISNULL(ST.State,''))) ,  
             currentpage = @n_CurrentPage, 
             DELNotes = ORDERS.deliverynote,
             OHNOTES = ORDERS.notes,   
             OHUDF02 = RTRIM(ORDERS.Userdefine02),   
             SSODROUTE = SSOD.[Route],
             CONTAINERQTY = ORDERS.ContainerQty,
             BD_Company = BD.company                                                  --CS01
      FROM ORDERS WITH (NOLOCK) 
      LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.CONSIGNEEKEY         --CS01
      LEFT JOIN Storersodefault SSOD (NOLOCK) ON SSOD.Storerkey = ST.Storerkey
      LEFT JOIN STORER BD WITH (NOLOCK) ON BD.Storerkey = ORDERS.Userdefine02         --CS01
      WHERE  ORDERS.OrderKey =  @c_ORDERNumber   
   END
END

GO