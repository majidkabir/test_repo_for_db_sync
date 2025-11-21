SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Delivery_Note49                                */  
/* Creation Date: 02-Oct-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15411 - ID - Request new format Delivery Noted Report   */
/*          for SYNGENTA (ID04)                                         */  
/*                                                                      */  
/* Called By: r_dw_delivery_note49                                      */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[isp_Delivery_Note49]
   @c_MBOLKey      NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue      INT = 1,
           @n_StartTCnt     INT,
           @b_success       INT,
           @n_err           INT,
           @c_errmsg        NVARCHAR(255)

   SELECT @n_StartTCnt = @@TRANCOUNT
   
   SELECT OH.Orderkey
         ,OH.Consigneekey
         ,OH.C_company
         ,ISNULL(OH.C_address1,'') AS C_address1
         ,ISNULL(OH.C_address2,'') AS C_address2
         ,ISNULL(OH.C_address3,'') AS C_address3
         ,ISNULL(OH.C_address4,'') AS C_address4
         ,ISNULL(OH.C_Zip,'') AS C_Zip
         ,ISNULL(OH.C_city,'') AS C_city
         ,ISNULL(OH.C_contact1,'') AS C_contact1
         ,ISNULL(OH.C_Phone1,'') AS C_Phone1
         ,OH.Facility
         ,OH.Storerkey
         ,CONVERT(NVARCHAR(10),OH.Deliverydate,105) AS Deliverydate
         ,OH.Mbolkey
         ,CONVERT(NVARCHAR(10),M.Shipdate,105) AS Shipdate
         ,ISNULL(OH.Notes,'') AS Notes
         ,SUBSTRING(ISNULL(S.DESCR,''),6,6) AS Hybrid
         ,S.Sku
         ,S.DESCR
         ,OD.Lottable02 AS ODLottable02
         ,L.Lottable02 AS LOTLottable02
         ,P.PackUOM3
         ,P.CaseCnt
         ,SUM(PD.Qty) AS PDQty
         ,CEILING((SUM(PD.Qty) / P.CaseCnt)) AS [Case]
         ,ISNULL(CL.Short,'N') AS RemoveLogo
         ,OH.Externorderkey
         ,ISNULL(M.OtherReference,'') AS Seal
         ,ISNULL(M.Vessel,'') AS Vessel
   FROM Orders OH WITH (NOLOCK)
   JOIN Orderdetail OD WITH (NOLOCK) ON OH.Storerkey = OD.Storerkey and OH.Orderkey = OD.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.SKU = OD.SKU
   JOIN LOTATTRIBUTE L WITH (NOLOCK) ON L.Lot = PD.Lot
   JOIN SKU S WITH (NOLOCK) ON S.StorerKey = OH.Storerkey AND S.SKU = OD.SKU
   JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PACKKey
   JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.OrderKey = OH.OrderKey
   JOIN MBOL M WITH (NOLOCK) ON M.MbolKey = MD.MbolKey
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (OH.Storerkey = CL.Storerkey AND CL.Listname='REPORTCFG' 
                                       AND CL.Long = 'r_dw_delivery_note49') AND CL.CODE = 'RemoveLogo'  
   WHERE MD.MbolKey = @c_MBOLKey
   GROUP BY OH.Orderkey
         ,OH.Consigneekey
         ,OH.C_company
         ,ISNULL(OH.C_address1,'')
         ,ISNULL(OH.C_address2,'')
         ,ISNULL(OH.C_address3,'')
         ,ISNULL(OH.C_address4,'')
         ,ISNULL(OH.C_Zip,'')
         ,ISNULL(OH.C_city,'')
         ,ISNULL(OH.C_contact1,'')
         ,ISNULL(OH.C_Phone1,'')
         ,OH.Facility
         ,OH.Storerkey
         ,CONVERT(NVARCHAR(10),OH.Deliverydate,105) 
         ,OH.Mbolkey
         ,CONVERT(NVARCHAR(10),M.Shipdate,105)
         ,ISNULL(OH.Notes,'')
         ,SUBSTRING(ISNULL(S.DESCR,''),6,6)
         ,S.Sku
         ,S.DESCR
         ,OD.Lottable02
         ,L.Lottable02
         ,P.PackUOM3
         ,P.CaseCnt
         ,ISNULL(CL.Short,'N')
         ,OH.Externorderkey
         ,ISNULL(M.OtherReference,'')
         ,ISNULL(M.Vessel,'')
      
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_Delivery_Note49'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
   
END -- End Procedure

GO