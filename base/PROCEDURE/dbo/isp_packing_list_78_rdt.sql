SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_Packing_List_78_rdt                            */
/* Creation Date: 10/06/2020                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose: WMS-13470  [CN] Sephora WMS_B2C_Handover_List               */
/*                                                                      */
/* Called By: r_dw_Packing_List_78_rdt                                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_78_rdt] (
   @c_storerkey     NVARCHAR(20),
   @c_palletkey     NVARCHAR(30)
   )
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF 

  
    SELECT DISTINCT 
                  o.externorderkey as externorderkey,
                  o.orderkey as orderkey,
                  o.trackingno as trackingno,
                  pk.weight as PIWGT,
                  --ISNULL(o.notes,'') as OHNotes,
                  '' as OHNotes,
                  o.mbolkey as mbolkey,
                  p.Palletkey as palletkey,
                  count(distinct pd.labelno) as cnt, 
                  o.ShipperKey + ' :' as shipperkey
   --FROM PalletDetail WITH (NOLOCK)
   --JOIN PackDetail WITH (NOLOCK) 
   --ON (PalletDetail.Storerkey = PackDetail.Storerkey AND PalletDetail.Caseid = PackDetail.Labelno AND PalletDetail.SKU = PackDetail.SKU)
   --JOIN PackHeader WITH (NOLOCK) ON (PackDetail.Pickslipno = PackHeader.Pickslipno)
   --JOIN Orders WITH (NOLOCK) ON (PackHeader.loadkey = Orders.loadkey)
   --JOIN PackInfo WITH (NOLOCK) ON (PackDetail.Pickslipno = PackInfo.Pickslipno AND PackDetail.Cartonno = PackInfo.Cartonno)
    FROM pallet p WITH (nolock) 
    JOIN mbol (nolock) m on p.palletkey = m.externmbolkey
   JOIN mboldetail (nolock) mb on m.mbolkey = mb.mbolkey
   JOIN orders (nolock) o on mb.orderkey = o.orderkey
   JOIN packheader (nolock) ph on o.loadkey = ph.loadkey
   JOIN packdetail (nolock) pd on ph.pickslipno = pd.pickslipno
   JOIN packinfo (nolock) pk on pd.pickslipno = pk.pickslipno and pd.cartonno = pk.cartonno 
   WHERE p.Storerkey = @c_storerkey 
      AND p.Palletkey =@c_palletkey 
   Group by  
            o.externorderkey ,
            o.orderkey,
            o.trackingno ,
            pk.weight,
            --ISNULL(o.notes,'') ,
            o.mbolkey,
            p.Palletkey,
            o.ShipperKey 

 END     


GO