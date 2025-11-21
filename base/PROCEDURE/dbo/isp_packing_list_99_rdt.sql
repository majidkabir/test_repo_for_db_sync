SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_99_RDT                                 */
/* Creation Date: 23-MAR-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-16592 - [CN] 511 TACTICAL PackingList CR                */
/*        :                                                             */
/* Called By: r_dw_packing_list_99_RDT                                  */
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
CREATE PROC [dbo].[isp_Packing_List_99_RDT]
            @c_PickSlipNo   NVARCHAR(10),
            @c_cartonNoStart NVARCHAR(5), 
            @c_cartonNoEnd NVARCHAR(5) 
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
     ,   SDESCR     = ISNULL(RTRIM(S.DESCR), '') 
     ,   O.Storerkey 
     ,   SSTYLE     = ISNULL(RTRIM(S.Style), '') 
     ,   PickSlipNo = PH.PickSlipNo 
     ,   Company    = ISNULL(RTRIM(O.B_Company), '')
     ,   Address1   = ISNULL(RTRIM(O.B_Address1), '')                      
     ,   Address2   = ISNULL(RTRIM(O.B_Address2), '')
     ,   Labelno    = ISNULL(RTRIM(PD.labelno), '')                       
     ,   SSUSR1     = ISNULL(RTRIM(S.susr1), '')                    
     ,   City       = ISNULL(RTRIM(O.B_City), '')                       
     ,   Zip        = ISNULL(RTRIM(O.B_Zip), '')                         
     ,   SBUSR1     = ISNULL(RTRIM(S.BUSR1), '')    
     ,   Contact1   = ISNULL(RTRIM(O.B_Contact1), '')                 
     ,   Phone1     =  ISNULL(RTRIM(O.B_Phone1), '')                      
     ,   BuyerPO    = ISNULL(RTRIM(O.BuyerPO), '') 
     ,   CartonNo   = ISNULL(PD.CartonNo, 0) 
     ,   TotalCarton= 1
     ,   PD.Sku
     ,   Qty        = ISNULL(SUM(PD.Qty),0)
     ,   TrackingNo = CT.TrackingNo
     ,   SSIZE     = ISNULL(RTRIM(S.Size), '') 
   FROM ORDERS     O  WITH (NOLOCK)
   JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)
                                    AND(S.Sku = PD.Sku)
   JOIN dbo.CartonTrack CT WITH (NOLOCK) ON CT.LabelNo=PD.LabelNo
   WHERE  PH.PickSlipNo = @c_PickSlipNo 
   AND PD.CartonNo >= CAST(@c_cartonNoStart AS INT) AND PD.CartonNo <= CAST(@c_cartonNoEnd AS INT)
   GROUP BY O.Orderkey 
        ,   ISNULL(RTRIM(S.DESCR), '') 
        ,   O.Storerkey 
        ,   ISNULL(RTRIM(S.Style), '') 
        ,   PH.PickSlipNo
        ,   ISNULL(RTRIM(O.ConsigneeKey), '') 
        ,   ISNULL(RTRIM(O.B_Company), '')
        ,   ISNULL(RTRIM(O.B_Address1), '')
        ,   ISNULL(RTRIM(O.B_Address2), '')
        ,   ISNULL(RTRIM(PD.LabelNo), '')
        ,   ISNULL(RTRIM(S.SUSR1), '')
        ,   ISNULL(RTRIM(O.B_City), '')
        ,   ISNULL(RTRIM(O.B_Zip), '')
        ,   ISNULL(RTRIM(S.BUSR1), '')
        ,   ISNULL(RTRIM(O.B_Contact1), '')
        ,   ISNULL(RTRIM(O.B_Phone1), '')
        ,   ISNULL(RTRIM(O.BuyerPO), '') 
        ,   O.Storerkey
        ,   ISNULL(PD.CartonNo, 0)
        ,   PD.Sku
        ,   CT.TrackingNo
        , ISNULL(RTRIM(S.Size), '')
   ORDER BY PH.PickSlipNo, ISNULL(PD.CartonNo, 0) ,ISNULL(RTRIM(PD.LabelNo), ''),PD.Sku   


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO