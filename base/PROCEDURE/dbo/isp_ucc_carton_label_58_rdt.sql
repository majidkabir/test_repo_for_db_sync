SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_58_rdt                             */
/* Creation Date: 14-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-1613 - bebe HK CPI - Carton Label                       */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_58_rdt                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_58_rdt] 
            @c_PickSlipNo     NVARCHAR(40) 
         ,  @c_CartonNoStart  NVARCHAR(4)     
         ,  @c_CartonNoEnd    NVARCHAR(4)     
         ,  @b_Debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_RS              INT

         , @c_Storerkey       NVARCHAR(15)
         , @c_Orderkey        NVARCHAR(10)
         , @c_CVRRoute        NVARCHAR(10)
         , @c_UDF01           NVARCHAR(60)
         , @c_refno           NVARCHAR(50)

         , @c_SQL             NVARCHAR(4000)
         , @c_Conditions      NVARCHAR(4000)


         --RCMREPORT 
         , @n_ShowPackRefNo   INT
         , @n_TTLPackQty      INT
         , @n_TTLPickQty      INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_TTLPackQty = 1
   SET @n_TTLPickqty = 1
   SET @c_refno = ''


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END 

   SET @c_Storerkey = ''

   SELECT @c_Storerkey = StorerKey
         ,@c_Orderkey = OrderKey
   FROM PACKHEADER WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   
   SELECT @n_TTLPackQty = SUM(qty)
   FROM packdetail (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   
   SELECT @n_TTLPickQty = SUM(qty)
   FROM PICKDETAIL (NOLOCK)
   WHERE Orderkey = @c_Orderkey
   AND STATUS ='5'
   

   SET @n_ShowPackRefNo = 0
   SELECT @n_ShowPackRefNo = ISNULL(MAX(CASE WHEN Code = 'ShowPackRefNo' THEN 1 ELSE 0 END),0)
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND Storerkey = @c_Storerkey
   AND Long = 'r_dw_ucc_carton_label_58_rdt'
   AND ISNULL(Short,'') <> 'N'
   
   IF @n_ShowPackRefNo = 1
   BEGIN
   	
   	SELECT @c_refno = (ISNULL(MAX(RTRIM(PACKDETAIL.REfNo)),'') + '/' +ISNULL(MAX(RTRIM(PACKDETAIL.REfNo2)),''))
   	FROM PACKDETAIL WITH (NOLOCK)
   	WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo
      AND  PACKDETAIL.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd
   	
   END 	

   SET @c_CVRRoute = ''
   DECLARE CUR_CLKUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(Notes), '')
         ,UDF01 = ISNULL(RTRIM(UDF01),'')
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = 'CVRRoute'
   AND    Storerkey= @c_Storerkey
   AND    Short    = 'ORDERS'
   ORDER BY Code
   
   OPEN CUR_CLKUP
   
   FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_RS = 0
      SET @c_SQL = N'SELECT @n_RS = 1'
                 + ' FROM ORDERS WITH (NOLOCK)'
                 + ' WHERE Orderkey = ''' + @c_Orderkey + ''''

      IF @c_Conditions <> ''
      BEGIN
         SET @c_SQL = @c_SQL + ' AND ' + @c_Conditions
      END

      EXECUTE sp_ExecuteSql @c_SQL, N'@n_RS INT OUTPUT', @n_RS OUTPUT

      SET @c_CVRRoute = @c_UDF01

      IF @n_RS > 0 
      BEGIN
         BREAK   
      END

      FETCH NEXT FROM CUR_CLKUP INTO @c_Conditions, @c_UDF01
   END
   CLOSE CUR_CLKUP
   DEALLOCATE CUR_CLKUP 
   
   SELECT DISTINCT 
          PH.PickSlipNo 
         ,PD.LabelNo
         ,PD.CartonNo
         ,PD.Storerkey
         ,ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,OH.Orderkey
         ,OH.Type
         ,Consigneekey  = ISNULL(RTRIM(OH.Consigneekey),'')
         ,C_Company     = ISNULL(RTRIM(OH.C_Company),'')
         ,C_Address1    = ISNULL(RTRIM(OH.C_Address1),'')
         ,C_Address2    = ISNULL(RTRIM(OH.C_Address2),'')
         ,C_Address3    = ISNULL(RTRIM(OH.C_Address3),'')
         ,C_Address4    = ISNULL(RTRIM(OH.C_Address4),'')
         ,C_City        = ISNULL(RTRIM(OH.C_City),'')
         ,C_State       = ISNULL(RTRIM(OH.C_State),'')
         ,C_Zip         = ISNULL(RTRIM(OH.C_Zip),'')
         ,C_Country     = ISNULL(RTRIM(OH.C_Country),'')
         ,Route         = ISNULL(RTRIM(OH.Route),'')
         ,DischargePlace= ISNULL(RTRIM(OH.DischargePlace),'')
         ,CVRRoute      = @c_CVRRoute
        -- ,RefNo         = CASE WHEN @n_ShowPackRefNo = 1 THEN (ISNULL(RTRIM(PD.REfNo),'') + '/' +ISNULL(RTRIM(PD.REfNo2),'')) ELSE '' END
         ,Refno            = @c_refno
         ,PrintDateTime = CONVERT(NVARCHAR(20), GETDATE(), 120)
         ,ST_Company   = ISNULL(RTRIM(STO.company),'')
         ,ST_BCompany  = ISNULL(RTRIM(STO.b_company),'')
         ,TTLCtn       = CASE WHEN @n_TTLPackQty = @n_TTLPickQty THEN 
         	                  CONVERT(NVARCHAR(10),(SELECT MAX(cartonno) AS TTLCtn FROM PACKDETAIL PDET WITH (NOLOCK) 
                            WHERE PDET.PickSlipNo = @c_PickSlipNo))
                            --AND  PDET.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd) )
                        ELSE '' END    
       --  ,TTLPackQty =@n_TTLPackQty
       --  ,TTLPickQty = @n_TTLPickQty                   
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   JOIN STORER     STO WITH (NOLOCK) ON STO.StorerKey = OH.StorerKey
   WHERE PH.PickSlipNo = @c_PickSlipNo
   AND  PD.CartonNo BETWEEN @c_CartonNoStart AND @c_CartonNoEnd
 --  AND  PD.LabelNo  BETWEEN @c_LabelNoStart AND @c_LabelNoEnd
   ORDER BY PD.CartonNo
           ,PD.LabelNo

QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_CLKUP') in (0 , 1)  
   BEGIN
      CLOSE CUR_CLKUP
      DEALLOCATE CUR_CLKUP
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
END -- procedure

GO