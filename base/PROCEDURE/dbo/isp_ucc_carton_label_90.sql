SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_UCC_Carton_Label_90                            */
/* Creation Date: 16-Aug-2019                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  To print the Ucc Carton Label 90                           */
/*           Copy from isp_ucc_carton_label_33                          */
/*                                                                      */
/* Input Parameters: Storerkey ,PickSlipNo, CartonNoStart, CartonNoEnd  */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_ucc_carton_label_90                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/*11/10/2019    WLChooi  1.1  WMS-10234 - Add new ReportCFG (WL01)      */
/*25/11/2019    WLChooi  1.2  WMS-10234 - Print extra barcode (WL02)    */
/*27/12/2019    WLChooi  1.3  WMS-11502 and Bug Fix - Qty (WL03)        */
/************************************************************************/

CREATE PROC [dbo].[isp_UCC_Carton_Label_90] (
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
         , @c_Facility        NVARCHAR(10)

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
   SET @c_Notes           = ''
   SET @c_Facility        = ''

   --WL03 Start
   CREATE TABLE #TEMP_EXTORDKEY(
   ExternOrderkey   NVARCHAR(50) )
   --WL03 End

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
         ,  ISNULL(RTRIM(ORDERS.Notes),'')   --WL01
         ,  ISNULL(RTRIM(ORDERS.Facility),'')
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
                                 ,@c_Notes
                                 ,@c_Facility

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --WL03 Start
      --IF LEN(@c_ExternOrderkey) > 0
      --BEGIN

      --   SET @c_ExternOrderkeys = @c_ExternOrderkeys + @c_ExternOrderkey + ', '
      --END
      INSERT INTO #TEMP_EXTORDKEY
      SELECT @c_ExternOrderkey
      --WL03 End

      FETCH NEXT FROM CUR_EXTSO INTO @c_ExternOrderkey
                                    ,@c_Consigneekey
                                    ,@c_C_Company
                                    ,@c_C_Address1
                                    ,@c_C_Address2
                                    ,@c_C_State
                                    ,@c_C_City
                                    ,@c_C_Contact1
                                    ,@c_C_Phone1
                                    ,@c_Notes              
                                    ,@c_Facility
   END
   CLOSE CUR_EXTSO
   DEALLOCATE CUR_EXTSO

   --WL03 Start
   --IF RIGHT(@c_ExternOrderkeys,2) = ', '
   --BEGIN
   --   --SET @c_ExternOrderkeys = SUBSTRING(@c_ExternOrderkeys, 1, LEN(@c_ExternOrderkeys) - 2)	--SOS353791
   --   SET @c_ExternOrderkeys = SUBSTRING(@c_ExternOrderkeys, 1, LEN(@c_ExternOrderkeys) - 1)		--SOS353791
   --END
   --SELECT @c_ExternOrderkeys = 'SA1234567890123' --MIN(ExternOrderkey) FROM #TEMP_EXTORDKEY
   SELECT @c_ExternOrderkeys = MIN(ExternOrderkey) FROM #TEMP_EXTORDKEY
   --WL03 End

   SELECT DISTINCT 
          PACKHEADER.Loadkey    AS Loadkey
         ,@c_ExternOrderkeys    AS ExternOrderkey
         ,@c_Consigneekey       AS Consigneekey
         ,@c_C_Company          AS C_Company
         ,@c_C_Address1         AS C_Address1
         ,@c_C_Address2         AS C_Address2
         ,@c_C_State            AS C_State
         ,@c_C_City             AS C_City
         ,@c_C_Contact1         AS C_Contact1
         ,@c_C_Phone1           AS C_Phone1
         ,PACKDETAIL.PickSlipNo AS PickSlipNo
         ,PACKDETAIL.CartonNo   AS CartonNo
         ,PACKDETAIL.LabelNo    AS LabelNo
         ,SUM(PACKDETAIL.Qty)   AS Qty
         ,LastCartonNo = ( SELECT ISNULL(COUNT(DISTINCT LabelNo),0) FROM PACKDETAIL PD WITH (NOLOCK)
                           WHERE PD.PickSlipNo = PACKDETAIL.PickSlipNo )
         ,ShowSubReport = CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END                        --CS01  
         ,@c_Notes AS notes                    
         ,ISNULL(S.B_ADDRESS4,'') AS b_addr4             
         ,CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN ISNULL(Packinfo.CartonGID,'') ELSE '' END AS CartonGID 
         ,ISNULL(CLR1.Short,'N') AS ShowBoldExtOrdKey --WL01
         ,ShowBarcode = 'N' --WL01
         ,ShowExtraBarcodeCFG = CASE WHEN ISNULL(CLR2.SHORT,'') = '' THEN 'N' ELSE 'Y' END --WL02
   INTO #Temp_90   --WL02
   FROM PACKHEADER WITH (NOLOCK)
   JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIl.PickSlipNo)
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (PACKHEADER.Storerkey = CLR.Storerkey AND CLR.Code = 'ShowSubReport'                                        
                                       AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_ucc_carton_label_90' AND ISNULL(CLR.Short,'') <> 'N') 
   LEFT JOIN STORER S WITH (NOLOCK) ON S.STORERKEY = @c_Consigneekey
   OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = PACKHEADER.STORERKEY AND CL.CODE = 'SUPERHUB' AND
               (CL.CODE2 = @c_Facility OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL 
   LEFT JOIN dbo.Packinfo WITH (NOLOCK) ON (dbo.PackDetail.Pickslipno = dbo.Packinfo.Pickslipno) 
                                         AND (dbo.PackDetail.CartonNo = dbo.Packinfo.CartonNo)
   LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (PACKHEADER.Storerkey = CLR1.Storerkey AND CLR1.Code = 'ShowBoldExtOrdKey'                              --WL01    
                                         AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_ucc_carton_label_90' AND ISNULL(CLR1.Short,'') <> 'N')--WL01
                                         AND LEFT(LTRIM(RTRIM(@c_ExternOrderkeys)),2) = 'SA' --WL01
   --JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Loadkey = PACKHEADER.Loadkey --WL02
   --JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY --WL02
   LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (CLR2.Short = @c_Consigneekey AND CLR2.Listname = 'skeprintTC')     --WL02           --WL03
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   AND   PACKHEADER.Storerkey = @c_StorerKey
   AND   PACKDETAIL.CartonNo BETWEEN @c_StartCartonNo AND @c_EndCartonNo
   GROUP BY PACKHEADER.Loadkey
         ,  PACKDETAIL.PickSlipNo
         ,  PACKDETAIL.CartonNo
         ,  PACKDETAIL.LabelNo
         ,  CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END             --CS01
         ,  ISNULL(S.B_ADDRESS4,'') 
         ,  CASE WHEN ISNULL(CL.Short,'N') = 'Y' THEN ISNULL(Packinfo.CartonGID,'') ELSE '' END
         ,  ISNULL(CLR1.Short,'N') --WL01
         ,  CASE WHEN ISNULL(CLR2.SHORT,'') = '' THEN 'N' ELSE 'Y' END --WL02

   INSERT INTO #Temp_90
   SELECT   ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , Pickslipno
          , CartonNo
          , LabelNo
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , ''
          , 'Y'
          , ''
   FROM #Temp_90 WHERE ShowExtraBarcodeCFG = 'Y'

   SELECT  Loadkey
         , ExternOrderkey
         , Consigneekey
         , C_Company
         , C_Address1
         , C_Address2
         , C_State
         , C_City
         , C_Contact1
         , C_Phone1
         , PickSlipNo
         , CartonNo
         , LabelNo
         , Qty
         , LastCartonNo
         , ShowSubReport
         , notes
         , b_addr4
         , CartonGID
         , ShowBoldExtOrdKey
         , ShowBarcode
   FROM #Temp_90
   ORDER BY Pickslipno, LabelNo, ShowBarcode

   IF OBJECT_ID('tempdb..#Temp_90') IS NOT NULL
      DROP TABLE #Temp_90

END


GO