SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackListBySku11                                     */
/* Creation Date: 01-MAY-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2553 - CN BROOKS PACKLIST                               */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_Sku11                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku11]
           @c_PickSlipNo   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

	SELECT O.Orderkey 
	  ,   ExternOrderKey = ISNULL(RTRIM(PH.OrderRefNo), '') 
	  ,   O.Storerkey 
	  ,   ST_Company = ISNULL(RTRIM(ST.Company), '') 
	  ,   PickSlipNo = PH.PickSlipNo 
	  ,   Company    = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Company), '')
	                        ELSE ISNULL(RTRIM(C.Company), '')
	                        END 
	                   + '(' + ISNULL(RTRIM(O.BillToKey), '') + '-' + ISNULL(RTRIM(O.ConsigneeKey), '') 
	                   + ')' 
	  ,   Address1   =  CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address1), '')
	                         ELSE ISNULL(RTRIM(C.Address1), '')
	                     END                           
	  ,   Address2   = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address2), '')
	                        ELSE ISNULL(RTRIM(C.Address2), '')
	                        END  
	  ,   Address3   = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address3), '')
	                        ELSE ISNULL(RTRIM(C.Address3), '')
	                        END                          
	  ,   Address4   = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Address4), '')
	                        ELSE ISNULL(RTRIM(C.Address4), '')
	                        END                        
	  ,   City       = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_City), '')
	                        ELSE ISNULL(RTRIM(C.City), '')
	                        END                            
	  ,   STATE      = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_State), '')
	                        ELSE ISNULL(RTRIM(C.State), '')
	                        END                           
	  ,   Country    = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Country), '')
	                        ELSE ISNULL(RTRIM(C.Country), '')
	                        END                            
	  ,   Contact1   = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Contact1), '')
	                        ELSE ISNULL(RTRIM(C.Contact1), '')
	                        END                   
	  ,   Phone1     = CASE WHEN C.Storerkey IS NULL THEN ISNULL(RTRIM(O.C_Phone1), '')
	                        ELSE ISNULL(RTRIM(C.Phone1), '')
	                        END                        
	  ,   BuyerPO    = ISNULL(RTRIM(O.BuyerPO), '') 
	  ,   CartonNo   = ISNULL(PD.CartonNo, 0) 
     ,   TotalCarton= (SELECT COUNT(DISTINCT CartonNo)FROM PACKDETAIL WITH (NOLOCK) WHERE PACKDETAIL.PickSlipNo = PH.PickSlipNo)
     ,   PD.Sku
     ,   Qty        = ISNULL(SUM(PD.Qty),0)
	FROM ORDERS     O  WITH (NOLOCK)
	JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)
	JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
	JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
	JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)
	                                 AND(S.Sku = PD.Sku)
	LEFT JOIN STORER C WITH (NOLOCK) ON (C.StorerKey = ISNULL(RTRIM(O.BillToKey), '') + ISNULL(RTRIM(O.ConsigneeKey), ''))
	WHERE  PH.PickSlipNo = @c_PickSlipNo 
   GROUP BY O.Orderkey 
	     ,   ISNULL(RTRIM(PH.OrderRefNo), '') 
	     ,   O.Storerkey 
	     ,   ISNULL(RTRIM(ST.Company), '') 
	     ,   PH.PickSlipNo
        ,   ISNULL(RTRIM(O.ConsigneeKey), '') 
	     ,   ISNULL(RTRIM(O.C_Company), '')
	     ,   ISNULL(RTRIM(O.BillToKey),'')
	     ,   ISNULL(RTRIM(O.C_Address1), '')
	     ,   ISNULL(RTRIM(O.C_Address2), '')
	     ,   ISNULL(RTRIM(O.C_Address3), '')
	     ,   ISNULL(RTRIM(O.C_Address4), '')
	     ,   ISNULL(RTRIM(O.C_City), '')
	     ,   ISNULL(RTRIM(O.C_State), '')
	     ,   ISNULL(RTRIM(O.C_Country), '')
	     ,   ISNULL(RTRIM(O.C_Contact1), '')
	     ,   ISNULL(RTRIM(O.C_Phone1), '')
	     ,   ISNULL(RTRIM(O.BuyerPO), '') 
        ,   C.Storerkey
	     ,   ISNULL(RTRIM(C.Company),'')
	     ,   ISNULL(RTRIM(C.Address1), '')
	     ,   ISNULL(RTRIM(C.Address2), '')
	     ,   ISNULL(RTRIM(C.Address3), '')
        ,   ISNULL(RTRIM(C.Address4), '')
	     ,   ISNULL(RTRIM(C.City), '')
	     ,   ISNULL(RTRIM(C.State), '')
	     ,   ISNULL(RTRIM(C.Country), '')
	     ,   ISNULL(RTRIM(C.Contact1), '')
	     ,   ISNULL(RTRIM(C.Phone1), '')
	     ,   ISNULL(PD.CartonNo, 0)
        ,   PD.Sku


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO