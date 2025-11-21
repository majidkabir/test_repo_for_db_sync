SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_106_RDT                                */
/* Creation Date: 29-JUL-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-17512-[CN] APEDEMOD_Packing list for Overseas B2B orders*/
/*        :                                                             */
/* Called By: r_dw_packing_list_106_RDT                                 */
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
CREATE PROC [dbo].[isp_Packing_List_106_RDT]
            @c_PickSlipNo   NVARCHAR(10),
            @c_cartonNoStart NVARCHAR(5) = '', 
            @c_cartonNoEnd NVARCHAR(5)  =''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SummPAck        NVARCHAR(5)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


  SET @c_SummPAck  = 'N'

   IF ISNULL(@c_cartonNoStart,'') = '' SET @c_cartonNoStart = '1'
   IF ISNULL(@c_cartonNoEnd,'') = '' SET @c_cartonNoEnd = '99999'

   IF @c_cartonNoStart ='1' AND @c_cartonNoEnd ='99999' 
   BEGIN 
        SET @c_SummPAck  = 'Y'     
   END

   SELECT O.ExternOrderKey 
     ,   SDESCR     = ISNULL(RTRIM(S.DESCR), '') --
     ,   O.Storerkey 
     ,   SCOLOR     = ISNULL(RTRIM(S.color), '') 
     ,   PickSlipNo = PH.PickSlipNo 
     ,   BPhone1    = ISNULL(RTRIM(O.B_Phone1), '')
     ,   BAddress1   = ISNULL(RTRIM(O.B_Address1), '')                      
     ,   BAddress2   = ISNULL(RTRIM(O.B_Address2), '')
     ,   CAddress1   = ISNULL(RTRIM(O.C_Address1), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address2), '')                        
     ,   CAddress3   = ISNULL(RTRIM(O.C_Address3), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address4), '')                     
     ,   BContact1  = ISNULL(RTRIM(O.B_contact1), '')                       
     ,   BAddress3  = ISNULL(RTRIM(O.B_Address3), '')  + SPACE(1)  + ISNULL(RTRIM(O.B_Address4), '')                      
     ,   CTCube     = ISNULL(PIF.[Cube],0.00)--ISNULL(CT.[Cube],0.00)
     ,   Contact1   = ISNULL(RTRIM(O.C_Contact1), '')      --           
     ,   Phone1     =  ISNULL(RTRIM(O.C_Phone1), '')                      
     ,   CCity      = ISNULL(RTRIM(O.C_City), '') 
     ,   CartonNo   = ISNULL(PD.CartonNo, 0) 
     ,   CState     = ISNULL(RTRIM(O.C_State), '')
     ,   PD.Sku
     ,   Qty        = ISNULL(SUM(PD.Qty),0)
     ,   GrossWGT   = ISNULL(PIF.weight,0.00) --ISNULL((S.GrossWgt + CT.CartonWeight),0.00)
     ,   SSIZE      = ISNULL(RTRIM(S.Size), '') 
    -- ,   CTCube    = CT.[Cube]
     ,   SUMMPACK  =@c_SummPAck 
   FROM ORDERS     O  WITH (NOLOCK)
   JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PD.Storerkey)
                                    AND(S.Sku = PD.Sku)
   JOIN PACKINFO PIF WITH (NOLOCK) ON PIF.PickSlipNo = PD.PickSlipNo AND PIF.CartonNo = PD.CartonNo
   --LEFT JOIN  dbo.CARTONIZATION CT WITH (NOLOCK) ON PH.cartongroup=CT.Cartonizationgroup and PH.ctntyp1=CT.CartonType
   JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.LISTNAME='APEDEPCK' AND C.Short = o.DocType AND C.long=o.ConsigneeKey AND UDF01='r_dw_packing_list_106_rdt'
   WHERE  PH.PickSlipNo = @c_PickSlipNo 
   AND PD.CartonNo >= CAST(@c_cartonNoStart AS INT) AND PD.CartonNo <= CAST(@c_cartonNoEnd AS INT)
   GROUP BY O.ExternOrderKey 
        ,   ISNULL(RTRIM(S.DESCR), '') 
        ,   O.Storerkey 
        ,   ISNULL(RTRIM(S.color), '') 
        ,   PH.PickSlipNo
        ,   ISNULL(RTRIM(O.ConsigneeKey), '') 
        ,   ISNULL(RTRIM(O.B_Phone1), '')
        ,   ISNULL(RTRIM(O.B_Address1), '')
        ,   ISNULL(RTRIM(O.B_Address2), '')
        ,   ISNULL(RTRIM(O.C_Address1), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address2), '') 
        ,   ISNULL(RTRIM(O.C_Address3), '')  + SPACE(1)  + ISNULL(RTRIM(O.C_Address4), '') 
        ,   ISNULL(RTRIM(O.B_contact1), '')
        ,   ISNULL(RTRIM(O.B_Address3), '') + SPACE(1)  + ISNULL(RTRIM(O.B_Address4), '')
        ,   ISNULL(RTRIM(S.BUSR1), '')
        ,   ISNULL(RTRIM(O.C_Contact1), '')
        ,   ISNULL(RTRIM(O.C_Phone1), '')
        ,   ISNULL(RTRIM(O.C_City), '') 
        ,   O.Storerkey
        ,   ISNULL(PD.CartonNo, 0)
        ,   PD.Sku
        ,   ISNULL(RTRIM(O.C_State), '')
        ,   ISNULL(RTRIM(S.Size), ''),ISNULL(PIF.[Cube],0.00),ISNULL(PIF.weight,0.00)--(S.GrossWgt + CT.CartonWeight), CT.[Cube]
   ORDER BY PH.PickSlipNo, ISNULL(PD.CartonNo, 0) ,PD.Sku   


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO