SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadSheet_Summ_02                              */
/* Creation Date: 04/06/2015                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 343653 - MY - Load Plan Summary Report                      */
/*                                                                      */
/* Called By: r_dw_loadsheet_summary_02                                 */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadSheet_Summ_02] (
@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_invoiceno NVARCHAR(10),
           @c_warehouse NVARCHAR(1),
           @c_prev_warehouse NVARCHAR(1),
           @n_key INT,
           @c_IDS_Company  NVARCHAR(45)
--
--   SET  @c_IDS_Company = ''
--
--   SELECT @c_IDS_Company = ISNULL(RTRIM(Company),'')
--   FROM STORER WITH (NOLOCK)
--   WHERE Storerkey = 'IDS'
--
--   IF @c_IDS_Company = ''
--   BEGIN
--      SET @c_IDS_Company = 'LF (Philippines), Inc.'
--   END

   select loadplandetail.loadkey,  
   storer.company,
   loadplandetail.consigneekey,
   loadplandetail.externorderkey,
   convert(char(10), loadplandetail.deliverydate, 5) as deliverydate,
   loadplandetail.orderkey,
   orders.route                     
   from loadplandetail  WITH (nolock)
   join loadplan WITH (nolock)on loadplandetail.loadkey = loadplan.loadkey
   join orders   WITH (nolock) on loadplandetail.orderkey = orders.orderkey
   --join facility WITH (nolock) on orders.facility = facility.facility
   left join routemaster WITH (nolock)on loadplan.route = routemaster.route
   join storer      WITH (nolock) on loadplandetail.consigneekey = storer.storerkey
   where loadplandetail.loadkey = @c_loadkey
END

GO