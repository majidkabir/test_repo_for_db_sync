SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PrintLoadMinifestLabel_01                      */
/* Creation Date: 30-July-2009                                          */
/* Copyright: IDS                                                       */
/* Written by: GT GOH                                                   */
/*                                                                      */
/* Purpose: To print Load manifest for C4 MY. (SOS#142933)              */
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
/* 25Aug2009	 GTGOH	  Take out Load Plan from label						*/
/*								  - SOS#145273												*/
/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintLoadMinifestLabel_01] (
       @cLoadKey       NVARCHAR(10) = '', 
	   @c_dropid       NVARCHAR(18) = '',
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
@c_ExternOrderKey   NVARCHAR(50),   --tlting_ext
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
        SELECT   ISNULL(LOADPLAN.LoadKey,'') AS LoadKey,    
            ISNULL(LOADPLAN.CarrierKey,'') AS CarrierKey,  
            ISNULL(LOADPLAN.MBOLKey,'') AS MBOLKey,
            ISNULL(LOADPLANDETAIL.ExternOrderKey,'') AS ExternOrderKey,
            ISNULL(LOADPLANDETAIL.Route,'') AS Route,  
            ISNULL(LOADPLANDETAIL.Door,'') AS Door,  
            ISNULL(LOADPLANDETAIL.Stop,'') AS Stop,  
            ISNULL(LOADPLANDETAIL.DeliveryDate,'') AS DeliveryDate,
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
        FROM PICKDETAIL   WITH (NOLOCK) 
            JOIN SKU     WITH (NOLOCK) ON ( PICKDETAIL.Storerkey = SKU.StorerKey ) and     
                                     ( PICKDETAIL.Sku = SKU.Sku )     
            JOIN ORDERS   WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey )     
            JOIN Storer WITH (NOLOCK) on ( Storer.StorerKey = ORDERS.ConsigneeKey )  
            JOIN PACK WITH (NOLOCK) on ( PACK.PackKey = PICKDETAIL.PackKey )  
	      LEFT OUTER JOIN LOADPLANDETAIL  WITH (NOLOCK) 
				ON ( LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey)     
				LEFT OUTER JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey      
				AND LOADPLAN.LoadKey   = @cLoadKey)
			WHERE ISNULL(PICKDETAIL.Qty,0) > 0  
			AND	  PICKDETAIL.DropID  = @c_dropid   
			Group by  ISNULL(LOADPLAN.LoadKey,''),    
					 ISNULL(LOADPLAN.CarrierKey,''),  
					 ISNULL(LOADPLAN.MBOLKey,''),
					 ISNULL(LOADPLANDETAIL.ExternOrderKey,''),
					 ISNULL(LOADPLANDETAIL.Route,''),  
					 ISNULL(LOADPLANDETAIL.Door,''),  
					 ISNULL(LOADPLANDETAIL.Stop,''),  
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
					 ISNULL(LOADPLANDETAIL.DeliveryDate,''),
					Storer.Address1, 
					Storer.Address2,
					Storer.Address3,
					Storer.Address4
			ORDER BY ISNULL(LOADPLAN.LoadKey,''),  PICKDETAIL.DropID, PICKDETAIL.LOC,  PICKDETAIL.SKU   
	
	OPEN @curSKU
	FETCH NEXT FROM @curSKU INTO @c_loadkey,   @c_carrierKey, @c_mbolkey, @c_ExternOrderKey,
                  @c_route,   @c_door, @c_stop, @d_deliverdate, 
				  @c_storerkey,   @c_SKU, @c_LOC, 
                  @c_dropid, @c_CartonGroup, @n_Qty,  @c_consigneekey, 
                  @c_company, @c_address1, @c_address2, @c_address3, @c_address4

	WHILE @@FETCH_STATUS <> -1
	BEGIN
      IF @b_debug  = 1
      BEGIN
         Select '@c_PrevKey', @c_PrevKey 
         SELECT '@c_loadkey + @c_dropid ' + @c_loadkey + @c_dropid
      END 

      If ISNULL(@c_PrevKey, '') <> ISNULL(@c_loadkey, '') + ISNULL(@c_dropid, '')
      BEGIN
         Set @n_cnt = 0
         Set @n_pageno = 1
         Select @c_PrevKey = ISNULL(@c_loadkey, '') + ISNULL(@c_dropid, '')
         
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
         deliverdate,   dropid,   storerkey,
         consigneekey,  company,      address1,
         address2,      address3,     address4,
         pageno,        CountID,      sku,
         LOC)
      values (@c_loadkey,   @c_carrierKey, @c_mbolkey,
         @c_route,   @c_door, @c_stop, 
         @d_deliverdate, @c_dropid, @c_storerkey,
         @c_consigneekey,  @c_company, @c_address1, 
         @c_address2, @c_address3, @c_address4,
         @n_pageno,     @n_CntID,    @c_SKU, 
         @c_LOC    )
       
	FETCH NEXT FROM @curSKU INTO @c_loadkey,   @c_carrierKey, @c_mbolkey, @c_ExternOrderKey,
                  @c_route,   @c_door, @c_stop, @d_deliverdate, 
                  @c_storerkey,   @c_SKU, @c_LOC, 
                  @c_dropid, @c_CartonGroup, @n_Qty,  @c_consigneekey, 
                  @c_company, @c_address1, @c_address2, @c_address3, @c_address4
	END

   Quit:
   SELECT loadkey,  carrierKey,    mbolkey,
            route,         door,         stop,      
            deliverdate,   dropid,   storerkey,
            consigneekey,  company,      address1,
            address2,      address3,     address4,
            pageno,        MinItem = convert(NVARCHAR(30), Min(LOC + sku)), 
            MaxItem = convert(NVARCHAR(30), Max(LOC + sku) ),
            totalPage = ( Select max(A.pageno) from @t_Result A where A.loadkey = loadkey AND A.dropid = dropid  ) ,
            CountID,     ( Select max(A.CountID) from @t_Result A where A.loadkey = loadkey  )     
   FROM @t_Result 
   Group by loadkey,  carrierKey,   mbolkey,
            route,         door,	stop,      
            deliverdate,   dropid,	storerkey,
            consigneekey,  company, address1,
            address2,      address3,address4,
            pageno,        CountID
   Order by loadkey, dropid, CountID, pageno
   

END

GO