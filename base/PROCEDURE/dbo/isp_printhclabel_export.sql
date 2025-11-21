SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PrintHCLabel_Export                            */  
/* Creation Date: 17-Oct-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by: TLTing                                                   */  
/*                                                                      */  
/* Purpose: To print Export Label for SG Healthcare  .                  */  
/*                                                                      */  
/* Called By: PB - Report Modules                                       */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_PrintHCLabel_Export] (  
       @cOrderKey      NVARCHAR(10) = '',   
       @nNoOfPackages  int = 1 ,   
       @cDimension     NVARCHAR(15) = '0',   
       @cWeight        NVARCHAR(15) = '0'   
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue    int,  
           @c_errmsg      NVARCHAR(255),  
           @b_success     int,  
           @n_err         int,   
           @b_debug       int  
  
   DECLARE @n_cnt int  
  
   DECLARE @t_Result Table (  
         StorerKey            NVARCHAR(15),  
         ExternOrderKey       NVARCHAR(50),  --tlting_ext  
         OrderKey             NVARCHAR(30),  
   C_Company            NVARCHAR(45),   
   C_Address1           NVARCHAR(45),   
   C_Address2           NVARCHAR(45),   
   C_Address3           NVARCHAR(45),   
   C_Address4           NVARCHAR(45),   
         Description          NVARCHAR(250),  
         company              NVARCHAR(45),  
   address1             NVARCHAR(45),  
   address2             NVARCHAR(45),  
   phone1               NVARCHAR(18),  
   phone2               NVARCHAR(18),  
         packages             int,  
         Total_packages       int,  
         PickSlipNo           NVARCHAR(10),  
         Dimension            NVARCHAR(15),  
         Weight               NVARCHAR(15),  
         rowid                int IDENTITY(1,1)   )  
  
  
   IF @b_debug = 1  
   BEGIN  
     
      SELECT O.StorerKey,  
         O.ExternOrderkey,  
               OrderNo = CASE WHEN LEN(O.ExternOrderkey) > 5 THEN Substring(O.ExternOrderkey, 6, LEN(O.ExternOrderkey)-5) ELSE '' END,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         CL.Description,  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2,  
               @n_cnt,  
               @nNoOfPackages,  
               PH.PickHeaderKey,  
               Dimension = @cDimension,  
               Weight = @cWeight  
        FROM Orders O (nolock)   
             JOIN Storer (nolock) on (storer.storerkey = O.storerkey)  
             JOIN OrderDetail OD (nolock) on (O.orderkey = OD.orderkey)   
             JOIN SKU (nolock) on (OD.storerkey = SKU.storerkey  
                               AND OD.sku = SKU.sku )   
             LEFT OUTER Join CodeLKUP CL (nolock) on (SKU.IVAS = CL.code)  
           JOIN PickHeader PH (nolock) ON PH.OrderKey = O.OrderKey   
      WHERE ( ISNULL(dbo.fnc_RTrim(@cOrderKey), '') = '' OR O.OrderKey = @cOrderKey)   
      GROUP BY O.StorerKey,  
         O.ExternOrderkey,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         CL.Description,  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2,  
               PH.PickHeaderKey  
  
   END  
  
   Set @n_cnt = 1  
   While @n_cnt <=  @nNoOfPackages     
   BEGIN  
      INSERT INTO @t_Result (StorerKey,         ExternOrderKey,         OrderKey,  
   C_Company,   C_Address1,    C_Address2,      
         C_Address3,   C_Address4,    Description,        
         company,         address1,   address2,  
   phone1,         phone2,           packages,  
         Total_packages,  
         PickSlipNo,          Dimension,        Weight )  
      SELECT O.StorerKey,  
         O.ExternOrderkey,  
               OrderNo = CASE WHEN LEN(O.ExternOrderkey) > 5 THEN Substring(O.ExternOrderkey, 6, LEN(O.ExternOrderkey)-5) ELSE '' END,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         CL.Description,  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2,  
               @n_cnt,  
               @nNoOfPackages,  
               PH.PickHeaderKey,  
               Dimension = @cDimension,  
               Weight = @cWeight  
        FROM Orders O (nolock)   
             JOIN Storer (nolock) on (storer.storerkey = O.storerkey)  
             JOIN OrderDetail OD (nolock) on (O.orderkey = OD.orderkey)   
             JOIN SKU (nolock) on (OD.storerkey = SKU.storerkey  
                               AND OD.sku = SKU.sku )   
             LEFT OUTER Join CodeLKUP CL (nolock) on (SKU.IVAS = CL.code)  
                   JOIN PickHeader PH (nolock) ON PH.OrderKey = O.OrderKey   
      WHERE ( ISNULL(dbo.fnc_RTrim(@cOrderKey), '') = '' OR O.OrderKey = @cOrderKey)   
      GROUP BY O.StorerKey,  
         O.ExternOrderkey,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         CL.Description,  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2,  
               PH.PickHeaderKey  
  
      Select @n_cnt = @n_cnt + 1  
   END  
  
     
Quit:  
   SELECT * FROM @t_Result   
   ORDER BY RowID   
END  

GO