SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PrintHCLabel_Outbound                          */  
/* Creation Date: 17-Oct-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: To print Outbound Label for SG Healthcare.                  */  
/*                                                                      */  
/* Called By: PB - Loadplan & Report Modules                            */  
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
  
CREATE PROC [dbo].[isp_PrintHCLabel_Outbound] (  
       @cLoadKey       NVARCHAR(10) = '',   
       @cPickSlipNo    NVARCHAR(10) = '',   
       @nNoOfPackages  int = 1  
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
   DeliveryDate         Datetime,  
   C_Company            NVARCHAR(45),   
   C_Address1           NVARCHAR(45),   
   C_Address2           NVARCHAR(45),   
   C_Address3           NVARCHAR(45),   
   C_Address4           NVARCHAR(45),   
   PmtTerm              NVARCHAR(10),   
         Sector               NVARCHAR(10),  
         TotalQty             int,  
         BuyerPO              NVARCHAR(20),  
         Description          NVARCHAR(250),  
         Remarks              NVARCHAR(250),  
         company              NVARCHAR(45),  
   address1             NVARCHAR(45),  
   address2             NVARCHAR(45),  
   phone1               NVARCHAR(18),  
   phone2               NVARCHAR(18),  
         packages             int,  
         Total_packages       int,  
         PickSlipNo           NVARCHAR(10),  
         rowid                int IDENTITY(1,1)   )  
  
  
   IF @b_debug = 1  
   BEGIN  
     
      SELECT O.StorerKey,  
         O.ExternOrderkey,  
         OrderNo = CASE WHEN LEN(O.ExternOrderkey) > 5 THEN Substring(O.ExternOrderkey, 6, LEN(O.ExternOrderkey)-5) ELSE '' END,  
         O.DeliveryDate,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         O.PmtTerm,   
         Sector = CASE WHEN (LEN(O.Route) > 4) THEN  Substring(O.Route, 5, (LEN(O.Route) - 4) ) ELSE '' END,  
         TotalQty = sum(OD.qtyAllocated + OD.qtypicked + OD.shippedqty),   
         O.BuyerPO,   
         CL.Description,  
         Remarks = Convert(NVARCHAR(250),O.Notes2),  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2,  
               @n_cnt,  
               @nNoOfPackages,  
               PH.PickHeaderKey  
        FROM Orders O (nolock)   
           JOIN Storer (nolock) on (storer.storerkey = O.storerkey)  
             JOIN OrderDetail OD (nolock) on (O.orderkey = OD.orderkey)   
             JOIN SKU (nolock) on (OD.storerkey = SKU.storerkey  
                               AND OD.sku = SKU.sku )   
             LEFT OUTER Join CodeLKUP CL (nolock) on (SKU.IVAS = CL.code)  
                   JOIN PickHeader PH (nolock) ON PH.OrderKey = O.OrderKey   
        WHERE ( ISNULL(dbo.fnc_RTrim(@cPickSlipNo), '') = '' OR PH.PickHeaderKey = @cPickSlipNo)   
        and   ( ISNULL(dbo.fnc_RTrim(@cLoadKey), '')    = '' OR O.loadkey = @cLoadKey )  
        GROUP BY    O.StorerKey,  
         O.ExternOrderkey,  
         O.DeliveryDate,  
         O.C_Company,   
         O.C_Address1,   
         O.C_Address2,  
         O.C_Address3,   
         O.C_Address4,   
         O.PmtTerm,   
         O.Route,   
         O.BuyerPO,   
         CL.Description,  
         Convert(NVARCHAR(250),O.Notes2),  
         Storer.company,  
         Storer.address1,  
         Storer.address2,  
         Storer.phone1,  
         Storer.phone2, PH.PickHeaderKey   
            ORDER BY O.ExternOrderkey, CL.Description  
  
   END  
  
   Set @n_cnt = 1  
   While @n_cnt <=  @nNoOfPackages     
   BEGIN  
      INSERT INTO @t_Result (StorerKey,         ExternOrderKey,         OrderKey,  
   DeliveryDate,   C_Company,   C_Address1,   
   C_Address2,    C_Address3,   C_Address4,   
   PmtTerm,             Sector,           TotalQty,  
         BuyerPO,             Description,      Remarks,  
         company,         address1,   address2,  
   phone1,         phone2,           packages,  
         Total_packages,      PickSlipNo )  
      SELECT O.StorerKey,  
      O.ExternOrderkey,  
      OrderNo = CASE WHEN LEN(O.ExternOrderkey) > 5 THEN Substring(O.ExternOrderkey, 6, LEN(O.ExternOrderkey)-5) ELSE '' END,  
      O.DeliveryDate,  
      O.C_Company,   
      O.C_Address1,   
      O.C_Address2,  
      O.C_Address3,   
      O.C_Address4,   
      O.PmtTerm,   
      Sector = CASE WHEN (LEN(O.Route) > 4) THEN  Substring(O.Route, 5, (LEN(O.Route) - 4) ) ELSE '' END,  
      TotalQty = sum(OD.qtyAllocated + OD.qtypicked + OD.shippedqty),   
      O.BuyerPO,   
      CL.Description,  
      Remarks = Convert(NVARCHAR(250),O.Notes2),  
      Storer.company,  
      Storer.address1,  
      Storer.address2,  
      Storer.phone1,  
      Storer.phone2,  
            @n_cnt,  
            @nNoOfPackages,  
            PH.PickHeaderKey  
     FROM Orders O (nolock)   
          JOIN Storer (nolock) on (storer.storerkey = O.storerkey)  
          JOIN OrderDetail OD (nolock) on (O.orderkey = OD.orderkey)   
          JOIN SKU (nolock) on (OD.storerkey = SKU.storerkey  
                            AND OD.sku = SKU.sku )   
          LEFT OUTER Join CodeLKUP CL (nolock) on (SKU.IVAS = CL.code)  
                JOIN PickHeader PH (nolock) ON PH.OrderKey = O.OrderKey   
     WHERE ( ISNULL(dbo.fnc_RTrim(@cPickSlipNo), '') = '' OR PH.PickHeaderKey = @cPickSlipNo)   
     and   ( ISNULL(dbo.fnc_RTrim(@cLoadKey), '')    = '' OR O.loadkey = @cLoadKey )  
     GROUP BY    O.StorerKey,  
      O.ExternOrderkey,  
      O.DeliveryDate,  
      O.C_Company,   
      O.C_Address1,   
      O.C_Address2,  
      O.C_Address3,   
      O.C_Address4,   
      O.PmtTerm,   
      O.Route,   
      O.BuyerPO,   
      CL.Description,  
      Convert(NVARCHAR(250),O.Notes2),  
      Storer.company,  
      Storer.address1,  
      Storer.address2,  
      Storer.phone1,  
      Storer.phone2, PH.PickHeaderKey   
         ORDER BY O.ExternOrderkey, CL.Description  
  
      Select @n_cnt = @n_cnt + 1  
   END  
  
     
Quit:  
   SELECT * FROM @t_Result   
   ORDER BY RowID   
END  

GO