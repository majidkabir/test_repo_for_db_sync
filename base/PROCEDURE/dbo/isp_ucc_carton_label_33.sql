SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_33                            */
/* Creation Date: 16-May-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  To print the Ucc Carton Label 33                           */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_33                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 29-Sep-2015  SPChin   1.1  SOS353791 - Bug Fixed                     */
/* 26-Apr-2017  CSCHONG  1.2  WMS-1683 - Add report config (CS01)       */
/* 04-Jan-2019  WLCHOOI  1.3  WMS-7486 - Add Order.Notes (WL01)         */
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_33] (
         @c_StorerKey      NVARCHAR(15)
      ,  @c_PickSlipNo     NVARCHAR(10)
      ,  @c_StartCartonNo  NVARCHAR(10)
      ,  @c_EndCartonNo    NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_ExternOrderkeys NVARCHAR(150)
         , @c_ExternOrderkey  NVARCHAR(50)  --tlting_ext
         , @c_Consigneekey    NVARCHAR(15)
         , @c_C_Company       NVARCHAR(45)
         , @c_C_Address1      NVARCHAR(45)
         , @c_C_Address2      NVARCHAR(45)
         , @c_C_State         NVARCHAR(45)
         , @c_C_City          NVARCHAR(45)
         , @c_C_Contact1      NVARCHAR(30)
         , @c_C_Phone1        NVARCHAR(30)
         , @c_Notes           NVARCHAR(250)						--WL01


   SET @c_ExternOrderkeys = ''
   SET @c_ExternOrderkey  = ''
   SET @c_Consigneekey    = ''
   SET @c_C_Company       = ''
   SET @c_C_Address1      = ''
   SET @c_C_Address2      = ''
   SET @c_C_State         = ''
   SET @c_C_City          = ''
   SET @c_C_Contact1      = ''
   SET @c_C_Phone1        = ''
   SET @c_Notes           = ''			--WL01

   DECLARE CUR_EXTSO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,  ISNULL(RTRIM(ORDERS.Consigneekey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Company),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,  ISNULL(RTRIM(ORDERS.C_State),'')
         ,  ISNULL(RTRIM(ORDERS.C_City),'')
         ,  ISNULL(RTRIM(ORDERS.C_Contact1),'')
         ,  ISNULL(RTRIM(ORDERS.C_Phone1),'')
         ,  ISNULL(TRIM(ORDERS.Notes),'')   --WL01
   FROM PACKHEADER WITH (NOLOCK)
   JOIN ORDERS     WITH (NOLOCK) ON (PACKHEADER.Loadkey = ORDERS.Loadkey)
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   AND   PACKHEADER.Storerkey = @c_StorerKey
   ORDER BY ORDERS.ExternOrderkey

   OPEN CUR_EXTSO

   FETCH NEXT FROM CUR_EXTSO INTO @c_ExternOrderkey
                                 ,@c_Consigneekey
                                 ,@c_C_Company
                                 ,@c_C_Address1
                                 ,@c_C_Address2
                                 ,@c_C_State
                                 ,@c_C_City
                                 ,@c_C_Contact1
                                 ,@c_C_Phone1
                                 ,@c_Notes           --WL01

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF LEN(@c_ExternOrderkey) > 0
      BEGIN

         SET @c_ExternOrderkeys = @c_ExternOrderkeys + @c_ExternOrderkey + ', '
      END
      FETCH NEXT FROM CUR_EXTSO INTO @c_ExternOrderkey
                                    ,@c_Consigneekey
                                    ,@c_C_Company
                                    ,@c_C_Address1
                                    ,@c_C_Address2
                                    ,@c_C_State
                                    ,@c_C_City
                                    ,@c_C_Contact1
                                    ,@c_C_Phone1
                                    ,@c_Notes               --WL01
   END
   CLOSE CUR_EXTSO
   DEALLOCATE CUR_EXTSO

   IF RIGHT(@c_ExternOrderkeys,2) = ', '
   BEGIN
      --SET @c_ExternOrderkeys = SUBSTRING(@c_ExternOrderkeys, 1, LEN(@c_ExternOrderkeys) - 2)	--SOS353791
      SET @c_ExternOrderkeys = SUBSTRING(@c_ExternOrderkeys, 1, LEN(@c_ExternOrderkeys) - 1)		--SOS353791
   END

   SELECT PACKHEADER.Loadkey
         ,@c_ExternOrderkeys
         ,@c_Consigneekey
         ,@c_C_Company
         ,@c_C_Address1
         ,@c_C_Address2
         ,@c_C_State
         ,@c_C_City
         ,@c_C_Contact1
         ,@c_C_Phone1
         ,PACKDETAIL.PickSlipNo
         ,PACKDETAIL.CartonNo
         ,PACKDETAIL.LabelNo
         ,SUM(PACKDETAIL.Qty)
         ,LastCartonNo = ( SELECT ISNULL(COUNT(DISTINCT LabelNo),0) FROM PACKDETAIL PD WITH (NOLOCK)
                           WHERE PD.PickSlipNo = PACKDETAIL.PickSlipNo )
         ,ShowSubReport = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END                       --CS01  
         ,@c_Notes                    --WL01
         ,ISNULL(S.B_ADDRESS4,'')     --WL01            
   FROM PACKHEADER WITH (NOLOCK)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIl.PickSlipNo)
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (PACKHEADER.Storerkey = CLR.Storerkey AND CLR.Code = 'ShowSubReport'                                        
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_33' AND ISNULL(CLR.Short,'') <> 'N') 
   LEFT JOIN STORER S WITH (NOLOCK) ON S.STORERKEY = @c_Consigneekey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   AND   PACKHEADER.Storerkey = @c_StorerKey
   AND   CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo
   GROUP BY PACKHEADER.Loadkey
         ,  PACKDETAIL.PickSlipNo
         ,  PACKDETAIL.CartonNo
         ,  PACKDETAIL.LabelNo
         , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END             --CS01
         , ISNULL(S.B_ADDRESS4,'') --WL01

END


GO