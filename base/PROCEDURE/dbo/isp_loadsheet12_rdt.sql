SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_LoadSheet12_rdt                                      */
/* Creation Date: 04-Jan-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-15922 - [PH] - Adidas Ecom - Loading Guide              */
/*                                                                      */
/* Called By:  r_dw_loadsheet12_rdt                                     */
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

CREATE PROC [dbo].[isp_LoadSheet12_rdt]  (
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
        , OH.Salesman
        , OH.DeliveryDate
        , PLTD.PalletKey
        , SUM(PD.Qty) AS Qty
        , 'PC' AS UOM
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN PALLETDETAIL PLTD (NOLOCK) ON PLTD.StorerKey = OH.StorerKey AND PLTD.UserDefine01 = OH.OrderKey
   WHERE LPD.LoadKey = @c_Loadkey
   GROUP BY OH.Loadkey
          , OH.Facility
          , OH.Storerkey
          , OH.Salesman
          , OH.DeliveryDate
          , PLTD.PalletKey
   
END

GO