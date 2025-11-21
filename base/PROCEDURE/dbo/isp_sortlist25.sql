SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_sortlist25                                          */
/* Creation Date: 13-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16036 - [PH] - Adidas Ecom - Sort List                  */
/*                                                                      */
/* Called By:  r_dw_sortlist25                                          */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_sortlist25]  (
           @c_Loadkey         NVARCHAR(10)
)
AS                                 
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT DISTINCT
          OH.Loadkey
        , OH.Facility
        , OH.Storerkey
        , OH.Shipperkey
        , OH.DeliveryDate
        , PD.DropID
        , PD.Sku
        , S.DESCR
        , SUM(PD.Qty) AS Qty
        , 'PC' AS UOM
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.SKU = PD.Sku
   WHERE LPD.LoadKey = @c_Loadkey
   GROUP BY OH.Loadkey
          , OH.Facility
          , OH.Storerkey
          , OH.Shipperkey
          , OH.DeliveryDate
          , PD.DropID
          , PD.Sku
          , S.DESCR
   
END

GO