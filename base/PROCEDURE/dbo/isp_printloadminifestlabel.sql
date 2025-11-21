SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
/************************************************************************/  
/* Stored Procedure: isp_PrintLoadMinifestLabel                          */  
/* Creation Date: 17-March-2007                                           */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: To print Load manifest for C4 TH.                           */  
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
  
CREATE PROC [dbo].[isp_PrintLoadMinifestLabel] (  
       @cLoadKey       NVARCHAR(10) = '',   
       @nMaxItem  int = 1      -- max no of item\sku in a label page  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF     
  
   DECLARE @n_continue    int,  
           @c_errmsg      NVARCHAR(255),  
           @b_success     int,  
           @n_err         int,   
           @b_debug       int  
  
Set @b_debug = 0  
  
   DECLARE @n_cnt int,  
@c_loadkey   NVARCHAR(10),  
@c_carrierKey   NVARCHAR(15),  
@c_mbolkey      NVARCHAR(10),  
@c_route         NVARCHAR(10),  
@c_door         NVARCHAR(10),  
@c_stop         NVARCHAR(10),  
@d_deliverdate   datetime,  
@d_scanoutdate   datetime,  
@c_dropid        NVARCHAR(18),  
@c_storerkey     NVARCHAR(15),  
@c_consigneekey  NVARCHAR(15),  
@c_company       NVARCHAR(45),  
@c_address1      NVARCHAR(45),  
@c_address2      NVARCHAR(45),  
@c_address3      NVARCHAR(45),  
@c_address4      NVARCHAR(45),  
@n_pageno        int,     
@c_sku      NVARCHAR(20),  
@c_LOC      NVARCHAR(10),  
@c_ExternOrderKey   NVARCHAR(50),  --tlting_ext  
@c_CartonGroup   NVARCHAR(10),    
@n_Qty           int,  
@c_PrevKey      NVARCHAR(30),  
@n_CntID         int  
   
  
   DECLARE @t_Result Table (  
         loadkey   NVARCHAR(10),  
         carrierKey   NVARCHAR(15),  
         mbolkey      NVARCHAR(10),  
         route         NVARCHAR(10),  
         door         NVARCHAR(10),  
         stop         NVARCHAR(10),  
         deliverdate   datetime,  
         scanoutdate   datetime,  
         dropid        NVARCHAR(18),  
         storerkey     NVARCHAR(15),  
         consigneekey  NVARCHAR(15),  
         company       NVARCHAR(45),  
         address1      NVARCHAR(45),  
         address2      NVARCHAR(45),  
         address3      NVARCHAR(45),  
         address4      NVARCHAR(45),  
         pageno        int,     
         CountID        int,     
         sku      NVARCHAR(20),  
         LOC      NVARCHAR(10),  
         rowid                int IDENTITY(1,1)   )  
  
  
    
  
   Set @n_cnt = 0  
   Set @c_PrevKey = ''  
   Set @n_pageno = 1  
   Set @n_CntID = 0  
  
  DECLARE @curSKU CURSOR  
   SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
        SELECT   LOADPLAN.LoadKey,      
            LOADPLAN.CarrierKey,    
            LOADPLAN.MBOLKey,  
            LOADPLANDETAIL.ExternOrderKey,  
            LOADPLANDETAIL.Route,    
            LOADPLANDETAIL.Door,    
      LOADPLANDETAIL.Stop,    
            LOADPLANDETAIL.DeliveryDate,  
            PickingInfo.ScanOutDate,  
            PICKDETAIL.Storerkey,     
            PICKDETAIL.SKU,    
            PICKDETAIL.LOC,    
            PICKDETAIL.DropID,     
            PICKDETAIL.CartonGroup,    
            Qty = SUM(ISNULL(PICKDETAIL.Qty,0)),       
            ORDERS.ConsigneeKey,    
            Storer.Company,   
    Storer.Address1,   
    Storer.Address2,  
    Storer.Address3,  
    Storer.Address4  
        FROM LOADPLAN (NOLOCK)       
            JOIN LOADPLANDETAIL  (NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey )       
            JOIN PICKDETAIL   (NOLOCK) ON ( PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey )       
            JOIN SKU     (NOLOCK) ON ( PICKDETAIL.Storerkey = SKU.StorerKey ) and       
                                     ( PICKDETAIL.Sku = SKU.Sku )       
            JOIN PICKHEADER   (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)       
            JOIN PickingInfo (NOLOCK) ON ( PickingInfo.PickSlipNo = PICKHEADER.PickHeaderKey )   
            JOIN ORDERS   (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey )       
            JOIN Storer (NOLOCK) on ( Storer.StorerKey = ORDERS.ConsigneeKey )    
            JOIN PACK (NOLOCK) on ( PACK.PackKey = PICKDETAIL.PackKey )    
        WHERE ISNULL(PICKDETAIL.Qty,0) > 0    
        AND   LOADPLAN.LoadKey   = @cLoadKey  
      Group by   LOADPLAN.LoadKey,      
            LOADPLAN.CarrierKey,    
            LOADPLAN.MBOLKey,  
            PickingInfo.ScanOutDate,  
                LOADPLANDETAIL.ExternOrderKey,  
                LOADPLANDETAIL.Route,    
                LOADPLANDETAIL.Door,    
                LOADPLANDETAIL.Stop,    
                PICKDETAIL.Storerkey,     
                PICKDETAIL.SKU,    
                PICKDETAIL.LOC,    
                PICKDETAIL.DropID,     
            PICKDETAIL.CartonGroup,    
                SKU.Descr,    
                ISNULL(SKU.StdGrossWGT, 0),    
                ISNULL(SKU.STDCube, 0),    
                ISNULL(PACK.CaseCnt, 0),    
                ISNULL(PACK.Pallet, 0),    
                ORDERS.ConsigneeKey,    
                Storer.Company,    
                LOADPLANDETAIL.DeliveryDate,  
            Storer.Address1,   
    Storer.Address2,  
    Storer.Address3,  
    Storer.Address4  
        ORDER BY LOADPLAN.LoadKey,  PICKDETAIL.DropID,             PICKDETAIL.LOC,  PICKDETAIL.SKU     
  
   
 OPEN @curSKU  
 FETCH NEXT FROM @curSKU INTO @c_loadkey,   @c_carrierKey, @c_mbolkey, @c_ExternOrderKey,  
                  @c_route,   @c_door, @c_stop, @d_deliverdate,   
                  @d_scanoutdate,  @c_storerkey,   @c_SKU, @c_LOC,   
                  @c_dropid, @c_CartonGroup, @n_Qty,  @c_consigneekey,   
                  @c_company, @c_address1, @c_address2, @c_address3, @c_address4  
  
 WHILE @@FETCH_STATUS <> -1  
 BEGIN  
  
      IF @b_debug  = 1  
      BEGIN  
         Select '@c_PrevKey', @c_PrevKey   
         SELECT '@c_loadkey + @c_dropid ' + @c_loadkey + @c_dropid  
      END   
  
      If @c_PrevKey <> @c_loadkey + @c_dropid  
      BEGIN  
         Set @n_cnt = 0  
         Set @n_pageno = 1  
         Select @c_PrevKey = @c_loadkey + @c_dropid  
           
         SELECT @n_CntID = @n_CntID + 1      -- count ID  
      END  
  
      Select @n_cnt = @n_cnt + 1  
  
     
      -- no of item cnt exceed Max item in a page  
      IF @n_cnt > ( @nMaxItem * @n_pageno )  
      BEGIN  
         Set @n_pageno = @n_pageno + 1  
  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         Select '@n_pageno', @n_pageno   
      END         
        
      INSERT INTO @t_Result ( loadkey,  carrierKey,    mbolkey,  
         route,         door,         stop,           
         deliverdate,   scanoutdate,   dropid,   storerkey,  
         consigneekey,  company,      address1,  
         address2,      address3,     address4,  
         pageno,        CountID,      sku,  
         LOC)  
      values (@c_loadkey,   @c_carrierKey, @c_mbolkey,  
      @c_route,   @c_door, @c_stop,   
         @d_deliverdate, @d_scanoutdate, @c_dropid, @c_storerkey,  
         @c_consigneekey,  @c_company, @c_address1,   
         @c_address2, @c_address3, @c_address4,  
         @n_pageno,     @n_CntID,    @c_SKU,   
         @c_LOC    )  
  
               
         
 FETCH NEXT FROM @curSKU INTO @c_loadkey,   @c_carrierKey, @c_mbolkey, @c_ExternOrderKey,  
                  @c_route,   @c_door, @c_stop, @d_deliverdate,   
                  @d_scanoutdate,  @c_storerkey,   @c_SKU, @c_LOC,   
                  @c_dropid, @c_CartonGroup, @n_Qty,  @c_consigneekey,   
                  @c_company, @c_address1, @c_address2, @c_address3, @c_address4  
 END  
  
  
    
Quit:  
   SELECT loadkey,  carrierKey,    mbolkey,  
         route,         door,         stop,        
         deliverdate,   scanoutdate,   dropid,   storerkey,  
         consigneekey,  company,      address1,  
         address2,      address3,     address4,  
         pageno,        MinItem = convert(NVARCHAR(30), Min(LOC + sku)),   
         MaxItem = convert(NVARCHAR(30), Max(LOC + sku) ),  
         totalPage = ( Select max(A.pageno) from @t_Result A where A.loadkey = loadkey AND A.dropid = dropid  ) ,  
         CountID,     ( Select max(A.CountID) from @t_Result A where A.loadkey = loadkey  )       
 FROM @t_Result   
Group by loadkey,  carrierKey,    mbolkey,  
         route,         door,         stop,        
         deliverdate,   scanoutdate,   dropid,   storerkey,  
         consigneekey,  company,      address1,  
         address2,      address3,     address4,  
         pageno,        CountID  
Order by loadkey, dropid, CountID, pageno  
  
  
END  
  

GO