SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Stored Proc: isp_Packing_List_99_2                                   */    
/* Creation Date: 18-Mar-2021                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: copy from isp_Packing_List_64_2                          */    
/*                                                                      */    
/* Purpose:WMS-16416 [TW] MLB PACKLIST Rcmreport CR                     */    
/*        :                                                             */    
/* Called By:r_dw_packing_list_99_2    (<> ECOM)                        */    
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
    
CREATE PROC [dbo].[isp_Packing_List_99_2]   
            @as_pickslipno     NVARCHAR(10)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue    INT = 1       
  
  --WL01 Remark Start  
 -- IF (@n_Continue = 1 OR @n_Continue = 2)  
 -- BEGIN       
 --     SELECT OH.Orderkey  
 --        ,OH.Storerkey  
 --        ,S_Company    = ISNULL(RTRIM(ST.Company),'')  
 --        ,ExternOrderkey=RTRIM(OH.ExternOrderkey) + '(' + RTRIM(OH.Type) + ')'  
 --        ,Loadkey      = CASE WHEN ISNULL(RTRIM(OH.UserDefine08),'') = 'Y'   
 --                             THEN 'W' + ISNULL(RTRIM(OH.UserDefine09),'')  
 --                             ELSE 'L' + ISNULL(RTRIM(OH.Loadkey),'')  
 --                             END  
 --        ,DeliveryDate = OH.DeliveryDate  
 --        ,Consigneekey = ISNULL(RTRIM(OH.Consigneekey),'')  
 --        ,C_Company    = ISNULL(RTRIM(OH.C_Company),'')  
 --        ,C_Address1   = ISNULL(RTRIM(OH.C_Address1),'')  
 --        ,C_Address2   = ISNULL(RTRIM(OH.C_Address2),'')  
 --        ,C_Address3   = ISNULL(RTRIM(OH.C_Address3),'')  
 --        ,C_Address4   = ISNULL(RTRIM(OH.C_Address4),'')  
 --        ,C_City       = ISNULL(RTRIM(OH.C_City),'')  
 --        ,C_Phone1     = ISNULL(RTRIM(OH.C_Phone1),'')   
 --        ,B_Company    = ISNULL(RTRIM(OH.B_Company),'')  
 --        ,B_Address1   = ISNULL(RTRIM(OH.B_Address1),'')  
 --        ,B_Address2   = ISNULL(RTRIM(OH.B_Address2),'')  
 --        ,B_Address3   = ISNULL(RTRIM(OH.B_Address3),'')  
 --        ,B_Address4   = ISNULL(RTRIM(OH.B_Address4),'')  
 --        ,B_City       = ISNULL(RTRIM(OH.B_City),'')  
 --        ,B_Phone1     = ISNULL(RTRIM(OH.B_Phone1),'')  
 --        ,ContainerQty = ISNULL(OH.ContainerQty,0)  
 --        ,NOTES        = ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES),'')  
 --        ,NOTES2       = ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES2),'')  
 --        ,UOM          = PK.PackUOM3  
 --        ,UserDefine06 = ISNULL(RTRIM(MIN(OD.UserDefine06)),'')  
 --        ,UserDefine09 = ISNULL(RTRIM(MIN(OD.UserDefine09)),'')  
 --        ,CartonNo     = PD.CartonNo  
 --        ,LabelNo      = ISNULL(RTRIM(PD.LabelNo),'')    
 --        ,SKU          = ISNULL(RTRIM(PD.Sku),'')     
 --        ,Qty          = (SELECT ISNULL(SUM(Qty),0) FROM PACKDETAIL WITH (NOLOCK) WHERE PickSlipNo = ISNULL(RTRIM(PH.PickSlipNo),'') AND CartonNo = PD.CartonNo  
 --                         AND Storerkey = OH.Storerkey AND Sku = ISNULL(RTRIM(PD.Sku),''))  
 --        ,AltSku       = ISNULL(RTRIM(SKU.AltSku),'')  
 --        ,Descr        = ISNULL(RTRIM(SKU.Descr),'')  
 --        ,PickSlipNo   = ISNULL(RTRIM(PH.PickSlipNo),'')  
 --        ,Invoice      = ISNULL(RTRIM(OH.InvoiceNo),'')  
 --        ,RPTLogo      = ISNULL(RTRIM(CL1.Long),'')  
 --FROM PACKHEADER      PH  WITH (NOLOCK)  
 --JOIN PACKDETAIL      PD  WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)  
 --JOIN ORDERS          OH  WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)  
 --JOIN ORDERDETAIL     OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)  
 --                                         AND(PD.Storerkey= OD.Storerkey) AND (PD.Sku = OD.Sku)  
 --JOIN STORER          ST  WITH (NOLOCK) ON (OH.Storerkey= ST.Storerkey)  
 --JOIN SKU             SKU WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey) AND (OD.Sku = SKU.Sku)  
 --JOIN PACK            PK  WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)  
 --LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON CL1.LISTNAME='RPTLogo' AND CL1.Storerkey=OH.Storerkey AND CL1.CODE = 'LVSPACK'  
 --WHERE (PH.PickSlipNo = @c_Pickslipno )  
 --AND   (OH.Status >= '5')  
 --AND   (OH.Status <> 'CANC')  
 --GROUP BY OH.Orderkey  
 --  ,  OH.Storerkey  
 --  ,  ISNULL(RTRIM(ST.Company),'')  
 --  ,  RTRIM(OH.ExternOrderkey)  
 --  ,  RTRIM(OH.Type)  
 --  ,  ISNULL(RTRIM(OH.UserDefine08),'')  
 --  ,  ISNULL(RTRIM(OH.UserDefine09),'')  
 --  ,  ISNULL(RTRIM(OH.Loadkey),'')  
 --  ,  OH.DeliveryDate  
 --  ,  ISNULL(RTRIM(OH.Consigneekey),'')  
 --  ,  ISNULL(RTRIM(OH.C_Company),'')  
 --  ,  ISNULL(RTRIM(OH.C_Address1),'')  
 --  ,  ISNULL(RTRIM(OH.C_Address2),'')  
 --  ,  ISNULL(RTRIM(OH.C_Address3),'')  
 --  ,  ISNULL(RTRIM(OH.C_Address4),'')  
 --  ,  ISNULL(RTRIM(OH.C_City),'')  
 --  ,  ISNULL(RTRIM(OH.C_Phone1),'')  
 --  ,  ISNULL(RTRIM(OH.B_Company),'')  
 --  ,  ISNULL(RTRIM(OH.B_Address1),'')  
 --  ,  ISNULL(RTRIM(OH.B_Address2),'')  
 --  ,  ISNULL(RTRIM(OH.B_Address3),'')  
 --  ,  ISNULL(RTRIM(OH.B_Address4),'')  
 --  ,  ISNULL(RTRIM(OH.B_City),'')  
 --  ,  ISNULL(RTRIM(OH.B_Phone1),'')  
 --  ,  ISNULL(OH.ContainerQty,0)  
 --  ,  ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES),'')  
 --  ,  ISNULL(CONVERT(NVARCHAR(4000), OH.NOTES2),'')  
 --  ,  PK.PackUOM3  
 --  ,  PD.CartonNo  
 --  ,  ISNULL(RTRIM(PD.LabelNo),'')  
 --  ,  ISNULL(RTRIM(PD.Sku),'')  
 --  ,  ISNULL(RTRIM(SKU.AltSku),'')  
 --  ,  ISNULL(RTRIM(SKU.Descr),'')  
 --  ,  OH.Notes   
 --  ,  OH.Notes2  
 --        ,  ISNULL(RTRIM(PH.PickSlipNo),'')  
 --  ,  ISNULL(RTRIM(OH.InvoiceNo),'')  
 --  ,  ISNULL(RTRIM(CL1.Long),'')  
 --ORDER BY RTRIM(OH.ExternOrderkey)  
 --  ,  PD.CartonNo  
 --  ,  ISNULL(RTRIM(PD.Sku),'')  
 --  END  
  --WL01 Remark End  
  
  --WL01 Start  
/* CODELKUP.REPORTCFG  
   [MAPFIELD]  
      DocKey, ReportHeading, ReportTitle, ReportTitle_M2, ReportTitle_M3  
      SplitPrintKey, OrderGrouping, Barcode, DocNumber, ExternOrderkey, Consigneekey  
      Wavekey, PickslipNo, DeliveryDate, BuyerPO, Brand  
      B_Company, B_Address, C_Company, C_Address, B_Company_M3, B_Address_M3, C_Company_M3, C_Address_M3  
      Remark, Instruction, CtnGrouping, LineGrouping, LineSort, InvoiceAmount  
      CartonSort, CartonNo, LabelNo, CartonWeight, CartonCBM, Dimenson, Refno, Refno2  
      Style, Color, Measurement, Size, SizeSort, Sku, Dept, Descr  
      LineRef, LineRef2, LineRef3, LineRemark, Qty, UOM, UnitPrice  
      ExtOrdKey_Summary  
   [MAPVALUE]  
      T_ExternOrderkey, T_DocNumber, T_Orderkey, T_ConsigneeKey  
      T_Wavekey, T_PickslipNo, T_DeliveryDate, T_BuyerPO, T_Brand, T_BillTo, T_B_Phone  
      T_ShipTo, T_C_Phone, T_Remark, T_Instruction, T_PO_No, T_Total_CBM, T_Total_Weight, T_InvoiceAmount, T_WeightUnit  
      T_CartonLabelNo, T_OriginalUCC, T_Carton_CBM, T_Carton_Weight, T_Dimension, T_LineNo, T_Style, T_Color, T_Size  
      T_Sku, T_Dept, T_Descr, T_UnitPrice, T_UnitPriceFormat, T_Qty  
      T_UOM, T_TotalPCE, T_LineRef, T_LineRef2, T_LineRef3, T_LineRemark,T_InvAmtCurrency, T_TotalCtnQty  
      T_Wavekey_M3, T_PickslipNo_M3, T_DeliveryDate_M3, T_BuyerPO_M3, T_Brand_M3, T_BillTo_M3, T_B_Phone_M3  
      T_ShipTo_M3, T_C_Phone_M3, T_PO_No_M3, T_Total_CBM_M3, T_Total_Weight_M3, T_InvoiceAmount_M3  
      T_CartonLabelNo_M3, T_OriginalUCC_M3, T_Carton_CBM_M3, T_Carton_Weight_M3, T_Dimension_M3  
      T_Exporter, T_ReportHeading, T_ReportTitle, T_ReportTitle_M2, T_ReportTitle_M3  
      T_OrderGroupTitle, T_OrderGroupTotalCarton, T_OrderGroupTotalQty, T_OrderGroupTotalWeight, T_OrderGroupTotalCBM  
      N_Xpos1, N_Xpos2, N_Xpos_Remark  
      N_Xpos_T_BillTo, N_Xpos_BillTo, N_Xpos_T_B_Phone, N_Xpos_B_Phone, N_Xpos_T_ShipTo, N_Xpos_ShipTo, N_Xpos_T_C_Phone, N_Xpos_C_Phone  
      N_Xpos_LabelNo, N_Xpos_OriginalUCC, N_Xpos_CartonWeight, N_Xpos_CartonCBM, N_Xpos_Dimension  
      N_Xpos_LineNo, N_Xpos_Style, N_Xpos_Color, N_Xpos_Size, N_Xpos_Sku, N_Xpos_Dept, N_Xpos_Descr, N_Xpos_UnitPrice  
      N_Xpos_Qty, N_Xpos_UOM, N_Xpos_TotalPCE, N_Xpos_LineRef, N_Xpos_LineRef2, N_Xpos_LineRef3, N_Xpos_LineRemark  
      N_Xpos_T_BillTo_M3, N_Xpos_BillTo_M3, N_Xpos_T_B_Phone_M3, N_Xpos_B_Phone_M3, N_Xpos_T_ShipTo_M3, N_Xpos_ShipTo_M3, N_Xpos_T_C_Phone_M3, N_Xpos_C_Phone_M3  
      N_Xpos_LabelNo_M3, N_Xpos_OriginalUCC_M3, N_Xpos_CartonWeight_M3, N_Xpos_CartonCBM_M3, N_Xpos_Dimension_M3  
      N_Xpos_LineNo_M3, N_Xpos_Style_M3, N_Xpos_Color_M3, N_Xpos_Size_M3, N_Xpos_Sku_M3, N_Xpos_Dept_M3, N_Xpos_Descr_M3, N_Xpos_UnitPrice_M3  
      N_Xpos_Qty_M3, N_Xpos_UOM_M3, N_Xpos_TotalPCE_M3, N_Xpos_LineRef_M3, N_Xpos_LineRef2_M3, N_Xpos_LineRef3_M3, N_Xpos_LineRemark_M3  
      N_Width_T_BillTo, N_Width_BillTo, N_Width_T_B_Phone, N_Width_B_Phone, N_Width_T_ShipTo, N_Width_ShipTo, N_Width_T_C_Phone, N_Width_C_Phone  
      N_Width_Remark, N_Width_T_LabelNo, N_Width_T_OriginalUCC, N_Width_T_CartonWeight, N_Width_T_CartonCBM, N_Width_T_Dimension  
      N_Width_LineNo, N_Width_Style, N_Width_Color, N_Width_Size, N_Width_Sku  
      N_Width_Dept, N_Width_Descr, N_Width_UnitPrice, N_Width_Qty, N_Width_UOM  
      N_Width_TotalPCE, N_Width_LineRef, N_Width_LineRef2, N_Width_LineRef3, N_Width_LineRemark  
      N_Height_BillTo, N_Height_ShipTo  
      T_ExtOrdKey_Summary, N_Col_ExtOrdKey_Summary, N_Width_ExtOrdKey_Summary  
   [SHOWFIELD]  
      ReportHeading_NoInvertColor, Logo, UseLFLogo, Barcode, UseCode39, OrderType, AddressDirectConcate, BuyerPO, Brand, StorerBillTo  
      City, State, Zip, Country, Contact, Fax, InvoiceAmount, Dimension  
      TotalCBM, TotalWeight, CartonCBM, CartonWeight  
      OriginalUCC, CartonDescription, CartonType, CartonNetWeightFormular2  
      LineNo, Dept, ChineseDescr, LineRef, LineRef2, LineRef3, LineRemark, ChineseLineRemark, TotalPCE, UnitPrice  
      TotalCBMM3, TotalWeightM3, CartonCBMM3, CartonWeightM3  
      LineNoM3, DeptM3, LineRefM3, LineRef2M3, LineRef3M3, LineRemarkM3, UnitPriceM3, TotalPCEM3  
      HidePrintAt, HideStorerkey, HideExternOrderkey, HideOrderkey, HideConsigneekey, HideWavekey, HidePickslipNo, HideDeliveryDate  
      HideBillToCompany, HideBillToAddress, HideBillToPhone, HideShipToCompany, HideShipToAddress, HideShipToPhone  
      HideRemark, HideInstruction, HideCartonNo, HideLabelNo, HideInvoiceAmount  
      HideStyle, HideColor, HideSize, HideSku, HideDescr, HideQty, HideUOM  
      HideTotalCarton, HideTotalQty  
      HidePrintAtM3, HideStorerkeyM3, HideExternOrderkeyM3, HideOrderkeyM3, HideConsigneekeyM3, HideWavekeyM3, HidePickslipNoM3, HideDeliveryDateM3  
      HideBillToCompanyM3, HideBillToAddressM3, HideBillToPhoneM3, HideShipToCompanyM3, HideShipToAddressM3, HideShipToPhoneM3  
      HideRemarkM3, HideInstructionM3, HideCartonNoM3, HideLabelNoM3, HideInvoiceAmountM3  
      HideStyleM3, HideColorM3, HideSizeM3, HideSkuM3, HideDescrM3, HideQtyM3, HideUOMM3  
      HideTotalCartonM3, HideTotalQtyM3  
      OrderGroupFooter, OrderGroupFooterM3  
     UseOrderBAddressM3, UseOrderCAddressM3, BuyerPOM3, BrandM3, OriginalUCCM3, ConsolPickSummary  
   [SQLJOIN]  
*/  
  
   --Since it is printed from Packing screen, only pickslipno will be passed in as parameter, so the snippet code below is not needed.  
   /*  
   DECLARE @n_Temp INT  
  
   IF LEN(@as_storerkey)=10 AND @as_storerkey LIKE 'P[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'  
   BEGIN  
      IF EXISTS(SELECT 1 FROM dbo.PACKHEADER (NOLOCK) WHERE PickslipNo=@as_storerkey)  
      BEGIN  
         SELECT @as_pickslipno     = @as_storerkey  
              , @n_Temp             = 0  
  
         SELECT @as_storerkey      = MAX(RTRIM(Storerkey))  
              , @n_Temp            = COUNT(DISTINCT Storerkey)  
           FROM dbo.PACKDETAIL (NOLOCK)  
          WHERE PickslipNo=@as_pickslipno AND Storerkey<>''  
  
         SELECT @as_storerkey      = CASE WHEN @n_Temp=1 THEN @as_storerkey ELSE CHAR(9) END  
              , @as_wavekey        = ''  
              , @as_loadkey        = ''  
              , @as_externorderkey = ''  
              , @as_orderkey       = ''  
              , @as_docmode        = '1'  
              , @as_sortbyinputseq = ''  
      END  
   END  
   ELSE IF LEN(@as_storerkey)=10 AND @as_storerkey LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'  
   BEGIN  
      IF EXISTS(SELECT 1 FROM dbo.WAVE (NOLOCK) WHERE Wavekey=@as_storerkey)  
      BEGIN  
         SELECT @as_wavekey        = @as_storerkey  
              , @n_Temp             = 0  
  
         SELECT @as_storerkey      = MAX(RTRIM(OH.Storerkey))  
              , @n_Temp            = COUNT(DISTINCT OH.Storerkey)  
           FROM dbo.WAVEDETAIL WD (NOLOCK)  
           JOIN dbo.ORDERS     OH (NOLOCK) ON WD.Orderkey=OH.Orderkey  
          WHERE WD.WaveKey=@as_wavekey AND OH.Storerkey<>''  
  
         SELECT @as_storerkey      = CASE WHEN @n_Temp=1 THEN @as_storerkey ELSE CHAR(9) END  
              , @as_loadkey        = ''  
              , @as_pickslipno     = ''  
              , @as_externorderkey = ''  
              , @as_orderkey       = ''  
              , @as_docmode        = '1'  
              , @as_sortbyinputseq = ''  
      END  
      ELSE IF EXISTS(SELECT 1 FROM dbo.LOADPLAN (NOLOCK) WHERE Loadkey=@as_storerkey)  
      BEGIN  
         SELECT @as_loadkey        = @as_storerkey  
              , @n_Temp             = 0  
  
         SELECT @as_storerkey      = MAX(RTRIM(Storerkey))  
              , @n_Temp            = COUNT(DISTINCT Storerkey)  
           FROM dbo.ORDERS (NOLOCK)  
          WHERE Loadkey=@as_loadkey AND Loadkey<>'' AND Storerkey<>''  
  
         SELECT @as_storerkey      = CASE WHEN @n_Temp=1 THEN @as_storerkey ELSE CHAR(9) END  
              , @as_wavekey        = ''  
              , @as_pickslipno     = ''  
              , @as_externorderkey = ''  
              , @as_orderkey       = ''  
              , @as_docmode        = '1'  
              , @as_sortbyinputseq = ''  
      END  
   END*/  
  
   DECLARE    @as_storerkey       NVARCHAR(15) = ''  
            , @as_wavekey         NVARCHAR(10) = ''  
            , @as_loadkey         NVARCHAR(10) = ''  
            , @as_externorderkey  NVARCHAR(4000) = ''  
            , @as_orderkey        NVARCHAR(4000) = ''  
            , @as_mbolkey         NVARCHAR(4000) = ''  
            , @as_docmode         NVARCHAR(10) = '1'  
            , @as_sortbyinputseq  NVARCHAR(10) = 'Y'  
  
   --Find the Storerkey, Orderkey from pickslipno (Discrete), Externorderkey  
   --Can find orderkey from pickslipno since it is discrete, one pickslipno one orderkey as mentioned in FBR (WMS-8102)  
   SELECT TOP 1  @as_storerkey      = Orders.Storerkey  
                ,@as_orderkey       = Orders.Orderkey  
                ,@as_externorderkey = Orders.ExternOrderKey  
                ,@as_loadkey        = Orders.LoadKey  
                ,@as_mbolkey        = Orders.MBOLKey  
                ,@as_wavekey        = Orders.Userdefine09   
   FROM Packheader (NOLOCK)  
   JOIN Orders (NOLOCK) on Orders.Orderkey = Packheader.Orderkey  
   WHERE Pickslipno = @as_pickslipno  
  
   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL  
      DROP TABLE #TEMP_PICKSLIPNO  
   IF OBJECT_ID('tempdb..#TEMP_ORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_ORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_EXTERNORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_EXTERNORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL  
      DROP TABLE #TEMP_FINALORDERKEY  
   IF OBJECT_ID('tempdb..#TEMP_PAKDT') IS NOT NULL  
      DROP TABLE #TEMP_PAKDT  
  
   DECLARE @c_DataWidnow         NVARCHAR(40)  
         , @c_SizeList           NVARCHAR(2000)  
         , @c_DocKeyExp          NVARCHAR(4000)  
         , @c_ReportHeadingExp   NVARCHAR(4000)  
         , @c_ReportTitleExp     NVARCHAR(4000)  
         , @c_ReportTitle_M2Exp  NVARCHAR(4000)  
         , @c_ReportTitle_M3Exp  NVARCHAR(4000)  
         , @c_SplitPrintKeyExp   NVARCHAR(4000)  
         , @c_OrderGroupingExp   NVARCHAR(4000)  
         , @c_BarcodeExp         NVARCHAR(4000)  
         , @c_DocNumberExp       NVARCHAR(4000)  
         , @c_ExternOrderkeyExp  NVARCHAR(4000)  
         , @c_ConsigneekeyExp    NVARCHAR(4000)  
         , @c_WavekeyExp         NVARCHAR(4000)  
         , @c_PickslipNoExp      NVARCHAR(4000)  
         , @c_DeliveryDateExp    NVARCHAR(4000)  
         , @c_BuyerPOExp         NVARCHAR(4000)  
         , @c_BrandExp           NVARCHAR(4000)  
         , @c_B_CompanyExp       NVARCHAR(4000)  
         , @c_B_AddressExp       NVARCHAR(4000)  
         , @c_C_CompanyExp       NVARCHAR(4000)  
         , @c_C_AddressExp       NVARCHAR(4000)  
         , @c_B_Company_M3Exp    NVARCHAR(4000)  
         , @c_B_Address_M3Exp    NVARCHAR(4000)  
         , @c_C_Company_M3Exp    NVARCHAR(4000)  
         , @c_C_Address_M3Exp    NVARCHAR(4000)  
         , @c_RemarkExp          NVARCHAR(4000)  
         , @c_InstructionExp     NVARCHAR(4000) --MY  
         , @c_CtnGroupingExp     NVARCHAR(4000)  
         , @c_LineGroupingExp    NVARCHAR(4000)  
         , @c_LineSortExp        NVARCHAR(4000)  
         , @c_InvoiceAmountExp   NVARCHAR(4000)  
         , @c_CartonSortExp      NVARCHAR(4000)  
         , @c_CartonNoExp        NVARCHAR(4000)  
         , @c_LabelNoExp         NVARCHAR(4000)  
         , @c_CartonWeightExp    NVARCHAR(4000)  
         , @c_CartonCBMExp       NVARCHAR(4000)  
         , @c_DimensonExp        NVARCHAR(4000)  
         , @c_RefnoExp           NVARCHAR(4000)  
         , @c_Refno2Exp          NVARCHAR(4000)  
         , @c_StyleExp           NVARCHAR(4000)  
         , @c_ColorExp           NVARCHAR(4000)  
         , @c_MeasurementExp     NVARCHAR(4000)  
         , @c_SizeExp            NVARCHAR(4000)  
         , @c_SizeSortExp        NVARCHAR(4000)  
         , @c_SkuExp             NVARCHAR(4000)  
         , @c_DeptExp            NVARCHAR(4000)  
         , @c_DescrExp           NVARCHAR(4000)  
         , @c_LineRefExp         NVARCHAR(4000)  
         , @c_LineRef2Exp        NVARCHAR(4000)  
         , @c_LineRef3Exp        NVARCHAR(4000)  
         , @c_LineRemarkExp      NVARCHAR(4000)  
         , @c_QtyExp             NVARCHAR(4000)  
         , @c_UOMExp             NVARCHAR(4000)  
         , @c_UnitpriceExp       NVARCHAR(4000)  
         , @c_ExtOrdKey_SumExp   NVARCHAR(4000)  
         , @n_PickslipNoCnt      INT  
         , @n_ExternOrderkeyCnt  INT  
         , @n_OrderkeyCnt        INT  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_ExecStatements     NVARCHAR(MAX)  
         , @c_ExecArguments      NVARCHAR(MAX)  
         , @c_JoinClause         NVARCHAR(4000)  
         , @n_Col                INT  
  
   SELECT @c_DataWidnow = 'r_dw_Packing_List_99'  
        , @c_SizeList   = N'|5XS|4XS|3XS|XXXS|2XS|XXS|XS|0XS|S|00S|YS|SM|0SM|S/M|M|00M|YM|ML|0ML|M/L|L|00L|YL|F|XL|0XL|XXL|2XL|XXXL|3XL|4XL|5XL|'  
        , @n_Col        = 5  
  
  
   CREATE TABLE #TEMP_PAKDT (  
        Orderkey         NVARCHAR(10)  
      , Storerkey        NVARCHAR(15)  
      , PickslipNo_key   NVARCHAR(18)  
      , ReportHeading    NVARCHAR(500)  
      , ReportTitle      NVARCHAR(500)  
      , ReportTitle_M2   NVARCHAR(500)  
      , ReportTitle_M3   NVARCHAR(500)  
      , SplitPrintKey    NVARCHAR(500)  
      , OrderGrouping    NVARCHAR(500)  
      , Barcode          NVARCHAR(500)  
      , DocNumber        NVARCHAR(500)  
      , ExternOrderkey   NVARCHAR(500)  
      , Consigneekey     NVARCHAR(500)  
      , Wavekey          NVARCHAR(500)  
      , PickslipNo       NVARCHAR(500)  
      , DeliveryDate     NVARCHAR(500)  
      , BuyerPO          NVARCHAR(500)  
      , Brand            NVARCHAR(500)  
      , B_Company        NVARCHAR(4000)  
      , B_Address        NVARCHAR(4000)  
      , C_Company        NVARCHAR(4000)  
      , C_Address        NVARCHAR(4000)  
      , B_Company_M3     NVARCHAR(4000)  
      , B_Address_M3     NVARCHAR(4000)  
      , C_Company_M3     NVARCHAR(4000)  
      , C_Address_M3     NVARCHAR(4000)  
      , Remark           NVARCHAR(500)  
      , Instruction      NVARCHAR(500)       --MY  
      , CtnGrouping      NVARCHAR(500)  
      , LineGrouping     NVARCHAR(500)  
      , LineSort         NVARCHAR(500)  
      , InvoiceAmount    NVARCHAR(500)  
      , Sku              NVARCHAR(500)  
      , Style            NVARCHAR(500)  
      , Color            NVARCHAR(500)  
      , Measurement      NVARCHAR(500)  
      , Size             NVARCHAR(500)  
      , SizeSeq          NVARCHAR(100)  
      , Descr            NVARCHAR(500)  
      , Dept             NVARCHAR(500)  
      , LineRef          NVARCHAR(500)  
      , LineRef2         NVARCHAR(500)  
      , LineRef3         NVARCHAR(500)  
      , LineRemark       NVARCHAR(500)  
      , CartonSort       NVARCHAR(500)  
      , CartonNo         INT  
      , LabelNo          NVARCHAR(500)  
      , CartonWeight     NVARCHAR(500)  
      , CartonCBM        NVARCHAR(500) NULL  
      , Dimenson         NVARCHAR(500) NULL  
      , LabelLine        NVARCHAR(5)   NULL  
      , DropID           NVARCHAR(20)  NULL  
      , RefNo            NVARCHAR(20)  NULL  
      , RefNo2           NVARCHAR(30)  NULL  
      , Qty              INT           NULL  
      , UOM              NVARCHAR(500) NULL  
      , Unitprice        FLOAT         NULL  
      , UPCCode          NVARCHAR(500) NULL   --WL02  
      , StdCube          FLOAT         NULL  
      , PrePackIndicator NVARCHAR(30)  NULL  
      , ConsolPick       NVARCHAR(1)   NULL  
      , DocKey           NVARCHAR(500) NULL  
      , FirstOrderkey    NVARCHAR(10)  NULL  
      , ExtOrdKey01      NVARCHAR(50)  NULL  
      , ExtOrdKey02      NVARCHAR(50)  NULL  
      , ExtOrdKey03      NVARCHAR(50)  NULL  
      , ExtOrdKey04      NVARCHAR(50)  NULL  
      , ExtOrdKey05      NVARCHAR(50)  NULL  
      , Section          NVARCHAR(1)   NULL  
  
   )  
  
   -- PickslipNo List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_PICKSLIPNO  
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_pickslipno,CHAR(13)+CHAR(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_PickslipNoCnt = @@ROWCOUNT  
  
   -- ExternOrderkey List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_EXTERNORDERKEY  
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_externorderkey,CHAR(13)+CHAR(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_ExternOrderkeyCnt = @@ROWCOUNT  
  
   -- Orderkey List  
   SELECT SeqNo    = MIN(SeqNo)  
        , ColValue = LTRIM(RTRIM(ColValue))  
     INTO #TEMP_ORDERKEY  
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_orderkey,CHAR(13)+CHAR(10),','))  
    WHERE ColValue<>''  
    GROUP BY LTRIM(RTRIM(ColValue))  
  
   SET @n_OrderkeyCnt = @@ROWCOUNT  
  
   -- Final Orderkey, PickslipNo List  
   CREATE TABLE #TEMP_FINALORDERKEY (  
        Orderkey         NVARCHAR(10)  
      , PickslipNo       NVARCHAR(10)  
      , Loadkey          NVARCHAR(10)  
      , ConsolPick       NVARCHAR(1)  
      , DocKey           NVARCHAR(10)  
      , Storerkey        NVARCHAR(15)  
   )  
   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'  
                        + ',@as_wavekey NVARCHAR(10)'  
                        + ',@as_loadkey NVARCHAR(10)'  
                        + ',@as_mbolkey NVARCHAR(10)'  
  
   -- Discrete Orders  
   SET @c_ExecStatements = N'INSERT INTO #TEMP_FINALORDERKEY'  
                         + ' SELECT Orderkey   = OH.Orderkey'  
                         +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'  
                         +       ', Loadkey    = MAX( OH.Loadkey )'  
                         +       ', ConsolPick = ''N'''  
                         +       ', DocKey     = MAX( OH.Orderkey )'  
                         +       ', Storerkey  = MAX( OH.Storerkey )'  
                         +   ' FROM dbo.ORDERS        OH (NOLOCK)'  
                         +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Orderkey = PIKHD.Orderkey AND OH.Orderkey<>'''''  
                         +   ' JOIN dbo.PACKHEADER    PH (NOLOCK) ON PIKHD.PickheaderKey = PH.PickslipNo'  
                         +   ' JOIN dbo.PACKDETAIL    PD (NOLOCK) ON PH.PickslipNo = PD.Pickslipno'  
                         +  ' WHERE OH.Status >= ''3'' AND OH.Status <= ''9'''  
                         +    ' AND PD.Qty > 0'  
   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR ISNULL(@as_mbolkey,'')<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0)  
   BEGIN  
      IF ISNULL(@as_storerkey,'')<>CHAR(9) AND ISNULL(@as_storerkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.Storerkey = @as_storerkey'  
      IF ISNULL(@as_wavekey,'')<>''  
         SET @c_ExecStatements += ' AND OH.Userdefine09 = @as_wavekey'  
      IF ISNULL(@as_loadkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.LoadKey = @as_loadkey'  
      IF ISNULL(@as_mbolkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.MBOLKey = @as_mbolkey'  
      IF @n_PickslipNoCnt>0  
         SET @c_ExecStatements += ' AND PH.PickSlipNo IN (SELECT ColValue FROM #TEMP_PICKSLIPNO)'  
      IF @n_ExternOrderkeyCnt>0  
         SET @c_ExecStatements += ' AND OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY)'  
      IF @n_OrderkeyCnt>0  
         SET @c_ExecStatements += ' AND OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY)'  
   END  
   ELSE  
   BEGIN  
      SET @c_ExecStatements += ' AND (1=2)'  
   END  
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'  
  
   EXEC sp_ExecuteSql @c_ExecStatements  
                    , @c_ExecArguments  
                    , @as_storerkey  
                    , @as_wavekey  
                    , @as_loadkey  
                    , @as_mbolkey  
  
   -- Consol Orders  
   SET @c_ExecStatements = N'INSERT INTO #TEMP_FINALORDERKEY'  
                         + ' SELECT Orderkey   = OH.Orderkey'  
                         +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'  
                         +       ', Loadkey    = MAX( OH.Loadkey )'  
                         +       ', ConsolPick = ''Y'''  
                         +       ', DocKey     = MAX( OH.Loadkey )'  
                         +       ', Storerkey  = MAX( OH.Storerkey )'  
                         +   ' FROM dbo.ORDERS        OH (NOLOCK)'  
                         +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Loadkey = PIKHD.ExternOrderkey AND ISNULL(PIKHD.Orderkey,'''')='''''  
                         +   ' JOIN dbo.PACKHEADER    PH (NOLOCK) ON PIKHD.PickheaderKey = PH.PickslipNo'  
                         +   ' JOIN dbo.PACKDETAIL    PD (NOLOCK) ON PH.PickslipNo = PD.Pickslipno'  
                         +   ' LEFT JOIN #TEMP_FINALORDERKEY  FOK ON OH.Orderkey = FOK.Orderkey'  
                         +  ' WHERE OH.Status >= ''3'' AND OH.Status <= ''9'''  
                         +    ' AND OH.Loadkey<>'''''  
                         +    ' AND PD.Qty > 0'  
                         +    ' AND FOK.Orderkey IS NULL'  
   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR ISNULL(@as_mbolkey,'')<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0)  
   BEGIN  
      IF ISNULL(@as_storerkey,'')<>CHAR(9) AND ISNULL(@as_storerkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.Storerkey = @as_storerkey'  
      IF ISNULL(@as_wavekey,'')<>''  
         SET @c_ExecStatements += ' AND OH.Userdefine09 = @as_wavekey'  
      IF ISNULL(@as_loadkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.LoadKey = @as_loadkey'  
      IF ISNULL(@as_mbolkey,'')<>''  
         SET @c_ExecStatements += ' AND OH.MBOLKey = @as_mbolkey'  
      IF @n_PickslipNoCnt>0  
         SET @c_ExecStatements += ' AND PH.PickSlipNo IN (SELECT ColValue FROM #TEMP_PICKSLIPNO)'  
      IF @n_ExternOrderkeyCnt>0  
         SET @c_ExecStatements += ' AND OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY)'  
      IF @n_OrderkeyCnt>0  
         SET @c_ExecStatements += ' AND OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY)'  
   END  
   ELSE  
   BEGIN  
      SET @c_ExecStatements += ' AND (1=2)'  
   END  
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'  
  
   EXEC sp_ExecuteSql @c_ExecStatements  
                    , @c_ExecArguments  
                    , @as_storerkey  
                    , @as_wavekey  
                    , @as_loadkey  
                    , @as_mbolkey  
  
   -- Storerkey Loop  
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Storerkey  
     FROM #TEMP_FINALORDERKEY  
    ORDER BY 1  
  
   OPEN C_STORERKEY  
  
   WHILE 1=1  
   BEGIN  
      FETCH NEXT FROM C_STORERKEY  
       INTO @c_Storerkey  
  
      IF @@FETCH_STATUS<>0  
         BREAK  
  
      SELECT @c_DocKeyExp          = ''  
           , @c_ReportHeadingExp   = ''  
           , @c_ReportTitleExp     = ''  
           , @c_ReportTitle_M2Exp  = ''  
           , @c_ReportTitle_M3Exp  = ''  
           , @c_SplitPrintKeyExp   = ''  
           , @c_OrderGroupingExp   = ''  
           , @c_BarcodeExp         = ''  
           , @c_DocNumberExp       = ''  
           , @c_ExternOrderkeyExp  = ''  
           , @c_ConsigneekeyExp    = ''  
           , @c_WavekeyExp         = ''  
           , @c_PickslipNoExp      = ''  
           , @c_DeliveryDateExp    = ''  
           , @c_BuyerPOExp         = ''  
           , @c_BrandExp           = ''  
           , @c_B_CompanyExp       = ''  
           , @c_B_AddressExp       = ''  
           , @c_C_CompanyExp       = ''  
           , @c_C_AddressExp       = ''  
           , @c_B_Company_M3Exp    = ''  
           , @c_B_Address_M3Exp    = ''  
           , @c_C_Company_M3Exp    = ''  
           , @c_C_Address_M3Exp    = ''  
           , @c_RemarkExp          = ''  
           , @c_InstructionExp     = ''   --MY  
           , @c_CtnGroupingExp     = ''  
           , @c_LineGroupingExp    = ''  
           , @c_LineSortExp        = ''  
           , @c_InvoiceAmountExp   = ''  
           , @c_CartonSortExp      = ''  
           , @c_CartonNoExp        = ''  
           , @c_LabelNoExp         = ''  
           , @c_CartonWeightExp    = ''  
           , @c_CartonCBMExp       = ''  
           , @c_DimensonExp        = ''  
           , @c_SkuExp             = ''  
           , @c_StyleExp           = ''  
           , @c_ColorExp           = ''  
           , @c_MeasurementExp     = ''  
           , @c_SizeExp            = ''  
           , @c_SizeSortExp        = ''  
           , @c_DescrExp           = ''  
           , @c_DeptExp            = ''  
           , @c_LineRefExp         = ''  
           , @c_LineRef2Exp        = ''  
           , @c_LineRef3Exp        = ''  
           , @c_LineRemarkExp      = ''  
           , @c_RefnoExp           = ''  
           , @c_Refno2Exp          = ''  
           , @c_QtyExp             = ''  
           , @c_UOMExp             = ''  
           , @c_UnitpriceExp       = ''  
           , @c_ExtOrdKey_SumExp   = ''  
           , @c_JoinClause         = ''  
  
      --WL02 START  
      DECLARE @c_Column    NVARCHAR(100) = '',  
              @c_Result    NVARCHAR(100) = '',  
 @c_SQL       NVARCHAR(MAX) = '',  
              @c_UPCCode   NVARCHAR(100) = '',  
              @c_UPCColumn NVARCHAR(100) = ''  
        
      SELECT @c_UPCColumn = LTRIM(RTRIM(ISNULL(CL.UDF02,'')))  
      FROM CODELKUP AS CL (NOLOCK)  
      WHERE CL.LISTNAME = 'REPORTCFG'  
      AND CL.Code = 'Col01'  
      AND CL.Storerkey = @c_storerkey  
      AND CL.Short = 'Y'  
      AND CL.Long = 'r_dw_packing_list_99_2'  
      --WL02 END  
        
      ----------  
      SELECT TOP 1  
             @c_JoinClause  = Notes  
        FROM dbo.CodeLkup (NOLOCK)  
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWidnow AND Short='Y'  
         AND Storerkey = @c_Storerkey  
       ORDER BY Code2  
  
  
      ----------  
      SELECT TOP 1  
             @c_DocKeyExp          = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocKey')), '' )  
           , @c_ReportHeadingExp   = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReportHeading')), '' )  
           , @c_ReportTitleExp     = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReportTitle')), '' )  
           , @c_ReportTitle_M2Exp  = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReportTitle_M2')), '' )  
           , @c_ReportTitle_M3Exp  = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReportTitle_M3')), '' )  
           , @c_SplitPrintKeyExp   = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='SplitPrintKey')), '' )  
           , @c_OrderGroupingExp   = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='OrderGrouping')), '' )  
           , @c_BarcodeExp         = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Barcode')), '' )  
           , @c_DocNumberExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocNumber')), '' )  
           , @c_ExternOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )  
           , @c_ConsigneekeyExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Consigneekey')), '' )  
           , @c_WavekeyExp         = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Wavekey')), '' )  
           , @c_PickslipNoExp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='PickslipNo')), '' )  
           , @c_DeliveryDateExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )  
           , @c_BuyerPOExp         = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='BuyerPO')), '' )  
           , @c_BrandExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Brand')), '' )  
           , @c_B_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Company')), '' )  
           , @c_B_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Address')), '' )  
           , @c_C_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )  
           , @c_C_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address')), '' )  
           , @c_B_Company_M3Exp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Company_M3')), '' )  
           , @c_B_Address_M3Exp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Address_M3')), '' )  
           , @c_C_Company_M3Exp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Company_M3')), '' )  
           , @c_C_Address_M3Exp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address_M3')), '' )  
           , @c_RemarkExp          = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Remark')), '' )  
           , @c_InstructionExp     = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Instruction')), '' )       --MY  
           , @c_CtnGroupingExp     = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='CtnGrouping')), '' )  
           , @c_LineGroupingExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineGrouping')), '' )  
           , @c_LineSortExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineSort')), '' )  
           , @c_InvoiceAmountExp   = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='InvoiceAmount')), '' )  
           , @c_CartonSortExp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonSort')), '' )  
           , @c_CartonNoExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonNo')), '' )  
           , @c_LabelNoExp         = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LabelNo')), '' )  
           , @c_CartonWeightExp    = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonWeight')), '' )  
           , @c_CartonCBMExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='CartonCBM')), '' )  
           , @c_DimensonExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Dimenson')), '' )  
           , @c_SkuExp             = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Sku')), '' )  
           , @c_StyleExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Style')), '' )  
           , @c_ColorExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Color')), '' )  
           , @c_MeasurementExp     = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Measurement')), '' )  
           , @c_SizeExp            = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Size')), '' )  
           , @c_SizeSortExp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='SizeSort')), '' )  
           , @c_DescrExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Descr')), '' )  
           , @c_DeptExp            = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Dept')), '' )  
           , @c_LineRefExp         = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef')), '' )  
           , @c_LineRef2Exp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef2')), '' )  
           , @c_LineRef3Exp        = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='LineRef3')), '' )  
           , @c_LineRemarkExp      = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRemark')), '' )  
           , @c_RefnoExp           = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Refno')), '' )  
           , @c_Refno2Exp          = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Refno2')), '' )  
           , @c_QtyExp             = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )  
           , @c_UOMExp             = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='UOM')), '' )  
           , @c_UnitPriceExp       = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='UnitPrice')), '' )  
           , @c_ExtOrdKey_SumExp   = ISNULL(RTRIM((select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExtOrdKey_Summary')), '' )  
        FROM dbo.CodeLkup (NOLOCK)  
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'  
         AND Storerkey = @c_Storerkey  
       ORDER BY Code2  
  
  
      ----------  
      IF ISNULL(@c_DocKeyExp,'')<>''  
      BEGIN  
         SET @c_ExecStatements = N'UPDATE FOK'  
                               + ' SET DocKey = ISNULL(RTRIM(' + @c_DocKeyExp + '),'''')'  
                               + ' FROM #TEMP_FINALORDERKEY FOK'  
                               + ' JOIN dbo.ORDERS          OH (NOLOCK) ON FOK.Orderkey = OH.Orderkey'  
                               + ' LEFT JOIN dbo.LOADPLAN   LP (NOLOCK) ON OH.Loadkey = LP.Loadkey AND OH.Loadkey<>'''''  
                               + ' LEFT JOIN dbo.WAVE       WP (NOLOCK) ON OH.Userdefine09 = WP.Wavekey AND OH.Userdefine09<>'''''  
                               + ' LEFT JOIN dbo.PACKHEADER PH (NOLOCK) ON FOK.PickslipNo = PH.PickslipNo'  
                               + ' WHERE FOK.Storerkey = @c_Storerkey'  
  
         SET @c_ExecArguments = N'@as_docmode NVARCHAR(10)'  
                              + ',@c_Storerkey NVARCHAR(15)'  
  
         EXEC sp_ExecuteSql @c_ExecStatements  
                          , @c_ExecArguments  
                          , @as_docmode  
                          , @c_Storerkey  
      END  
  
  
      IF OBJECT_ID('tempdb..#TEMP_FINALPICKSLIPNO') IS NOT NULL  
      DROP TABLE #TEMP_FINALPICKSLIPNO  
      IF OBJECT_ID('tempdb..#TEMP_ORDERLINENUMBER') IS NOT NULL  
      DROP TABLE #TEMP_ORDERLINENUMBER  
  
      SELECT DISTINCT  
             PickslipNo     = FOK.PickslipNo  
           , DocKey         = FOK.DocKey  
           , Loadkey        = FOK.Loadkey  
           , ConsolPick     = FOK.ConsolPick  
           , Orderkey       = FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)  
      INTO #TEMP_FINALPICKSLIPNO  
      FROM #TEMP_FINALORDERKEY FOK  
      WHERE FOK.Storerkey = @c_Storerkey  
  
  
      SELECT DocKey          = X.DocKey  
           , Storerkey       = X.Storerkey  
           , Sku             = X.Sku  
           , Orderkey        = LEFT(X.Sourcekey,10)  
           , OrderLineNumber = SUBSTRING(X.Sourcekey,11,5)  
      INTO #TEMP_ORDERLINENUMBER  
      FROM (  
       SELECT FOK.DocKey, OD.Storerkey, OD.Sku, Sourcekey=MIN(LEFT(OD.Orderkey+SPACE(10),10)+OD.OrderLineNumber)  
         FROM #TEMP_FINALORDERKEY FOK  
         JOIN dbo.ORDERDETAIL OD(NOLOCK) ON FOK.Orderkey=OD.Orderkey  
        WHERE FOK.Storerkey = @c_Storerkey  
        GROUP BY FOK.DocKey, OD.Storerkey, OD.Sku  
      ) X  
  
  
      ----------  
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'  
          +' (Orderkey, Storerkey, ReportHeading, ReportTitle, ReportTitle_M2, ReportTitle_M3'  
          + ', SplitPrintKey, OrderGrouping, Barcode, DocNumber, ExternOrderkey, Consigneekey'  
          + ', Wavekey, PickslipNo, PickslipNo_key, DeliveryDate, BuyerPO, Brand'  
          + ', B_Company, B_Address, C_Company, C_Address, B_Company_M3, B_Address_M3, C_Company_M3, C_Address_M3'  
          + ', Remark, Instruction, CtnGrouping, LineGrouping, LineSort, InvoiceAmount, Sku'   --MY  
          + ', Style, Color, Measurement, Size, SizeSeq'  
          + ', Descr, Dept, LineRef, LineRef2'  
          + ', LineRef3, LineRemark, CartonSort, CartonNo, LabelNo, CartonWeight, CartonCBM, Dimenson'  
          + ', LabelLine, DropID, RefNo, RefNo2, Qty'  
          + ', UOM, UnitPrice, UPCCode, StdCube, PrePackIndicator'   --WL02  
          + ', ConsolPick, DocKey, FirstOrderkey, Section)'  
          +' SELECT OH.OrderKey'  
               + ', OH.Storerkey'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReportHeadingExp  ,'')<>'' THEN @c_ReportHeadingExp   ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReportTitleExp    ,'')<>'' THEN @c_ReportTitleExp     ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReportTitle_M2Exp ,'')<>'' THEN @c_ReportTitle_M2Exp  ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReportTitle_M3Exp ,'')<>'' THEN @c_ReportTitle_M3Exp  ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SplitPrintKeyExp  ,'')<>'' THEN @c_SplitPrintKeyExp   ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderGroupingExp  ,'')<>'' THEN @c_OrderGroupingExp   ELSE ''''''                     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BarcodeExp        ,'')<>'' THEN @c_BarcodeExp         ELSE 'UPPER(IIF(FOK.ConsolPick=''Y'',FOK.DocKey,OH.ExternOrderkey))' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp      ,'')<>'' THEN @c_DocNumberExp       ELSE 'UPPER(IIF(FOK.ConsolPick=''Y'',FOK.DocKey,OH.ExternOrderkey))' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp ,'')<>'' THEN @c_ExternOrderkeyExp  ELSE 'UPPER(OH.ExternOrderkey)' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
 + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneekeyExp   ,'')<>'' THEN @c_ConsigneekeyExp    ELSE 'UPPER(OH.Consigneekey)'   END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_WavekeyExp        ,'')<>'' THEN @c_WavekeyExp         ELSE 'UPPER(OH.Userdefine09)'   END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PickslipNoExp     ,'')<>'' THEN @c_PickslipNoExp      ELSE 'UPPER(PH.PickSlipNo)'     END + '),'''')'  
               + ', UPPER(PH.PickSlipNo)'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DeliveryDateExp   ,'')<>'' THEN @c_DeliveryDateExp    ELSE 'CONVERT(CHAR(10),OH.DeliveryDate,103)' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BuyerPOExp        ,'')<>'' THEN @c_BuyerPOExp         ELSE 'OH.BuyerPO'        END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BrandExp          ,'')<>'' THEN @c_BrandExp           ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_CompanyExp      ,'')<>'' THEN @c_B_CompanyExp       ELSE 'OH.B_Company'      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_AddressExp      ,'')<>'' THEN @c_B_AddressExp       ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp      ,'')<>'' THEN @c_C_CompanyExp       ELSE 'OH.C_Company'      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_AddressExp      ,'')<>'' THEN @c_C_AddressExp       ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_Company_M3Exp   ,'')<>'' THEN @c_B_Company_M3Exp    ELSE 'CX.B_Company'      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_Address_M3Exp   ,'')<>'' THEN @c_B_Address_M3Exp    ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Company_M3Exp   ,'')<>'' THEN @c_C_Company_M3Exp    ELSE 'CX.Company'        END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_Address_M3Exp   ,'')<>'' THEN @c_C_Address_M3Exp    ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RemarkExp         ,'')<>'' THEN @c_RemarkExp          ELSE 'ISNULL(LTRIM(RTRIM(OH.Notes2)),'''')' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InstructionExp    ,'')<>'' THEN @c_InstructionExp    ELSE 'ISNULL(LTRIM(RTRIM(OH.Notes)),'''')' END + '),'''')'  --MY  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CtnGroupingExp    ,'')<>'' THEN @c_CtnGroupingExp     ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineGroupingExp   ,'')<>'' THEN @c_LineGroupingExp    ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineSortExp       ,'')<>'' THEN @c_LineSortExp        ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceAmountExp  ,'')<>'' THEN @c_InvoiceAmountExp   ELSE '''~'''             END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuExp            ,'')<>'' THEN @c_SkuExp             ELSE 'PD.Sku'            END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StyleExp          ,'')<>'' THEN @c_StyleExp           ELSE 'SKU.Style'         END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ColorExp          ,'')<>'' THEN @c_ColorExp           ELSE 'SKU.Color'         END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_MeasurementExp    ,'')<>'' THEN @c_MeasurementExp     ELSE 'SKU.Measurement'   END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(LTRIM(RTRIM(' + CASE WHEN ISNULL(@c_SizeExp     ,'')<>'' THEN @c_SizeExp            ELSE 'SKU.Size'          END + ')),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SizeSortExp       ,'')<>'' THEN @c_SizeSortExp        ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DescrExp          ,'')<>'' THEN @c_DescrExp           ELSE 'SKU.DESCR'         END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DeptExp           ,'')<>'' THEN @c_DeptExp            ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRefExp        ,'')<>'' THEN @c_LineRefExp         ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef2Exp       ,'')<>'' THEN @c_LineRef2Exp        ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef3Exp       ,'')<>'' THEN @c_LineRef3Exp        ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemarkExp     ,'')<>'' THEN @c_LineRemarkExp      ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonSortExp     ,'')<>'' THEN @c_CartonSortExp      ELSE ''''''              END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CartonNoExp       ,'')<>'' THEN @c_CartonNoExp        ELSE 'PD.CartonNo'       END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelNoExp        ,'')<>'' THEN @c_LabelNoExp         ELSE 'PD.LabelNo'        END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ' + CASE WHEN ISNULL(@c_CartonWeightExp,'')<>'' THEN 'ISNULL(RTRIM('+@c_CartonWeightExp+'),'''')' ELSE 'NULL' END  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ' + CASE WHEN ISNULL(@c_CartonCBMExp   ,'')<>'' THEN 'ISNULL(RTRIM('+@c_CartonCBMExp   +'),'''')' ELSE 'NULL' END  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ' + CASE WHEN ISNULL(@c_DimensonExp    ,'')<>'' THEN 'ISNULL(RTRIM('+@c_DimensonExp    +'),'''')' ELSE 'NULL' END  
               + ', PD.LabelLine'  
               + ', PD.DropID'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RefnoExp          ,'')<>'' THEN @c_RefnoExp           ELSE 'PD.RefNo'          END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Refno2Exp         ,'')<>'' THEN @c_Refno2Exp          ELSE 'PD.RefNo2'         END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_QtyExp            ,'')<>'' THEN @c_QtyExp             ELSE 'PD.Qty'            END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UOMExp            ,'')<>'' THEN @c_UOMExp             ELSE 'PACK.PackUOM3'     END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UnitPriceExp      ,'')<>'' THEN @c_UnitPriceExp       ELSE 'OD.UnitPrice'      END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements   --WL02  
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UPCColumn         ,'')<>'' THEN @c_UPCColumn          ELSE ''''''              END + '),'''')'   --WL02  
      SET @c_ExecStatements = @c_ExecStatements  
               + ', SKU.StdCube'  
               + ', SKU.PrePackIndicator'  
               + ', FOK.ConsolPick'  
               + ', FOK.DocKey'  
               + ', FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)'  
               + ', ''1'''  
          +' FROM dbo.ORDERS      OH (NOLOCK)'  
          +' JOIN #TEMP_FINALPICKSLIPNO FOK   ON OH.Orderkey=FOK.Orderkey'  
          +' JOIN dbo.PACKHEADER  PH (NOLOCK) ON FOK.PickslipNo=PH.PickslipNo'  
          +' JOIN dbo.PACKDETAIL  PD (NOLOCK) ON PH.PickslipNo=PD.PickslipNo'  
          +' JOIN dbo.SKU        SKU (NOLOCK) ON PD.StorerKey=SKU.StorerKey AND PD.Sku=SKU.Sku'  
          +' JOIN dbo.PACK      PACK (NOLOCK) ON SKU.PACKKey=PACK.PackKey'  
          +' JOIN dbo.STORER      ST (NOLOCK) ON OH.StorerKey=ST.StorerKey'  
          +' LEFT JOIN dbo.PACKINFO PI (NOLOCK) ON PD.PickslipNo=PI.PickslipNo AND PD.CartonNo=PI.CartonNo'  
          +' LEFT JOIN ('  
          +' SELECT CartonType        = CartonType'  
               + ', CartonDescription = MAX(CartonDescription)'  
               + ', Cube              = MAX(Cube)'  
               + ', CartonWeigth      = MAX(CartonWeight)'  
               + ', CartonLength      = MAX(CartonLength)'  
               + ', CartonWidth       = MAX(CartonWidth)'  
               + ', CartonHeight      = MAX(CartonHeight)'  
           + ' FROM dbo.CARTONIZATION (NOLOCK)'  
           + ' GROUP BY CartonType'  
          + ') CT ON PI.CartonType = CT.CartonType'  
          +' LEFT JOIN dbo.STORER CX (NOLOCK) ON CX.Storerkey=''PL-''+RTRIM(OH.Storerkey)+''-''+ ISNULL(OH.C_Country,'''')'  
          +' LEFT JOIN #TEMP_ORDERLINENUMBER ORDET ON FOK.DocKey=ORDET.DocKey AND PD.Storerkey=ORDET.Storerkey AND PD.Sku=ORDET.Sku'  
          +' LEFT JOIN dbo.ORDERDETAIL OD (NOLOCK) ON ORDET.Orderkey=OD.Orderkey AND ORDET.OrderLineNumber=OD.OrderLineNumber'  
      SET @c_ExecStatements = @c_ExecStatements  
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END  
      SET @c_ExecStatements = @c_ExecStatements  
          +' WHERE PD.Qty > 0 AND OH.Storerkey=@c_Storerkey'  
  
      SET @c_ExecArguments = N'@as_docmode          NVARCHAR(10)'  
                           + ',@c_Storerkey         NVARCHAR(15)'  
  
      EXEC sp_ExecuteSql @c_ExecStatements  
                       , @c_ExecArguments  
                       , @as_docmode  
                       , @c_Storerkey  
  
      -- ExternOrderKey Summary (Section = 2)  
      SET @c_ExecStatements = N'INSERT INTO #TEMP_PAKDT'  
          +' (Orderkey, Storerkey, PickslipNo_key, ReportHeading, ReportTitle'  
          +', ReportTitle_M2, ReportTitle_M3, SplitPrintKey, OrderGrouping, Barcode, DocNumber'  
          +', ExternOrderkey, Consigneekey, Wavekey, PickslipNo, DeliveryDate'  
          +', BuyerPO, Brand, B_Company, B_Address, C_Company'  
          +', C_Address, B_Company_M3, B_Address_M3, C_Company_M3, C_Address_M3'  
      +', Remark, Instruction, InvoiceAmount, ConsolPick, DocKey, FirstOrderkey, Sku'   --MY  
          +', ExtOrdKey01, ExtOrdKey02, ExtOrdKey03, ExtOrdKey04, ExtOrdKey05'  
          +', Section)'  
      SET @c_ExecStatements = @c_ExecStatements  
          +' SELECT Orderkey       = MAX(PAKDT.Orderkey)'  
          +      ', Storerkey      = X.Storerkey'  
          +      ', PickslipNo_key = MAX(PAKDT.PickslipNo_key)'  
          +      ', ReportHeading  = MAX(PAKDT.ReportHeading)'  
          +      ', ReportTitle    = MAX(PAKDT.ReportTitle)'  
          +      ', ReportTitle_M2 = MAX(PAKDT.ReportTitle_M2)'  
          +      ', ReportTitle_M3 = MAX(PAKDT.ReportTitle_M3)'  
          +      ', SplitPrintKey  = MAX(PAKDT.SplitPrintKey)'  
          +      ', OrderGrouping  = MAX(PAKDT.OrderGrouping)'  
          +      ', Barcode        = MAX(PAKDT.Barcode)'  
          +      ', DocNumber      = MAX(PAKDT.DocNumber)'  
          +      ', ExternOrderkey = MAX(PAKDT.ExternOrderkey)'  
          +      ', Consigneekey   = MAX(PAKDT.Consigneekey)'  
          +      ', Wavekey        = MAX(PAKDT.Wavekey)'  
          +      ', PickslipNo     = MAX(PAKDT.PickslipNo)'  
          +      ', DeliveryDate   = MAX(PAKDT.DeliveryDate)'  
          +      ', BuyerPO        = MAX(PAKDT.BuyerPO)'  
          +      ', Brand          = MAX(PAKDT.Brand)'  
          +      ', B_Company      = MAX(PAKDT.B_Company)'  
          +      ', B_Address      = MAX(PAKDT.B_Address)'  
          +      ', C_Company      = MAX(PAKDT.C_Company)'  
          +      ', C_Address      = MAX(PAKDT.C_Address)'  
          +      ', B_Company_M3   = MAX(PAKDT.B_Company_M3)'  
          +      ', B_Address_M3   = MAX(PAKDT.B_Address_M3)'  
          +      ', C_Company_M3   = MAX(PAKDT.C_Company_M3)'  
          +      ', C_Address_M3   = MAX(PAKDT.C_Address_M3)'  
          +      ', Remark         = MAX(PAKDT.Remark)'  
          +      ', Instruction    = MAX(PAKDT.Instruction)'     --MY  
          +      ', InvoiceAmount  = MAX(PAKDT.InvoiceAmount)'  
          +      ', ConsolPick     = MAX(PAKDT.ConsolPick)'  
          +      ', DocKey         = X.DocKey'  
          +      ', FirstOrderkey  = MAX(PAKDT.FirstOrderkey)'  
          +      ', Sku            = FORMAT( FLOOR((X.SeqNo-1) / X.N_Col), ''0000000000'')'  
          +      ', ExtOrdKey01    = MAX( CASE WHEN (X.SeqNo-1) % X.N_Col = 0 THEN X.ExternOrderKey ELSE '''' END )'  
          +      ', ExtOrdKey02    = MAX( CASE WHEN (X.SeqNo-1) % X.N_Col = 1 THEN X.ExternOrderKey ELSE '''' END )'  
          +      ', ExtOrdKey03    = MAX( CASE WHEN (X.SeqNo-1) % X.N_Col = 2 THEN X.ExternOrderKey ELSE '''' END )'  
          +      ', ExtOrdKey04    = MAX( CASE WHEN (X.SeqNo-1) % X.N_Col = 3 THEN X.ExternOrderKey ELSE '''' END )'  
          +      ', ExtOrdKey05    = MAX( CASE WHEN (X.SeqNo-1) % X.N_Col = 4 THEN X.ExternOrderKey ELSE '''' END )'  
          +      ', Section        = ''2'''  
      SET @c_ExecStatements = @c_ExecStatements  
          +' FROM ('  
          +  ' SELECT Storerkey, DocKey, ExternOrderkey, SeqNo'  
          +        ', N_Col = CASE WHEN ISNUMERIC(C_Col)=1 AND CONVERT(INT, CONVERT(FLOAT, C_Col)) BETWEEN 1 AND 5 THEN CONVERT(INT, CONVERT(FLOAT, C_Col)) ELSE @n_Col END'  
          +  ' FROM ('  
          +     ' SELECT Storerkey      = FOK.Storerkey'  
          +           ', DocKey         = FOK.DocKey'  
      SET @c_ExecStatements = @c_ExecStatements  
          +           ', ExternOrderkey = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExtOrdKey_SumExp,'')<>'' THEN @c_ExtOrdKey_SumExp ELSE 'OH.ExternOrderkey' END + '),'''')'  
      SET @c_ExecStatements = @c_ExecStatements  
          +           ', SeqNo          = ROW_NUMBER() OVER(PARTITION BY FOK.Storerkey, FOK.DocKey ORDER BY OH.ExternOrderkey)'  
          +           ', C_Col          = CAST( RTRIM( (select top 1 b.ColValue'  
          +                                ' from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b'  
          +                                ' where a.SeqNo=b.SeqNo and a.ColValue=''N_Col_ExtOrdKey_Summary'') ) AS VARCHAR(50))'  
          +     ' FROM #TEMP_FINALORDERKEY FOK'  
          +     ' JOIN dbo.ORDERS OH (NOLOCK) ON FOK.Orderkey=OH.Orderkey'  
          +     ' JOIN ('  
          +        ' SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))'  
          +              ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'  
          +          ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''SHOWFIELD'' AND Long=@c_DataWidnow AND Short=''Y'''  
          +     ' ) RptCfg'  
          +     ' ON RptCfg.Storerkey=FOK.Storerkey AND RptCfg.SeqNo=1'  
      SET @c_ExecStatements = @c_ExecStatements  
          +     ' LEFT JOIN ('  
          +        ' SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))'  
          +              ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'  
          +          ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''MAPVALUE'' AND Long=@c_DataWidnow AND Short=''Y'''  
          +     ' ) RptCfg3'  
          +     ' ON RptCfg3.Storerkey=FOK.Storerkey AND RptCfg3.SeqNo=1'  
          +     ' WHERE FOK.Storerkey=@c_Storerkey AND FOK.ConsolPick = ''Y'' AND RptCfg.ShowFields LIKE ''%,ConsolPickSummary,%'''  
          +   ') Y'  
          + ') X'  
      SET @c_ExecStatements = @c_ExecStatements  
          +' JOIN #TEMP_PAKDT PAKDT ON X.Storerkey=PAKDT.Storerkey AND X.DocKey=PAKDT.DocKey'  
          +' GROUP BY X.Storerkey, X.DocKey, FLOOR((X.SeqNo-1) / X.N_Col)'  
  
      SET @c_ExecArguments = N'@c_Storerkey  NVARCHAR(15)'  
                           + ',@c_DataWidnow NVARCHAR(40)'  
                           + ',@n_Col        INT'  
  
      EXEC sp_ExecuteSql @c_ExecStatements  
                       , @c_ExecArguments  
                       , @c_Storerkey  
                       , @c_DataWidnow  
                       , @n_Col  
   END  
  
   CLOSE C_STORERKEY  
   DEALLOCATE C_STORERKEY  
  
  
   ----------  
   IF ISNULL(@c_SizeSortExp,'')=''  
   BEGIN  
      UPDATE #TEMP_PAKDT SET SizeSeq =  
         CASE WHEN ISNUMERIC(Size)=1 AND LTRIM(Size) NOT IN ('-','+','.',',') THEN FORMAT(CONVERT(FLOAT,Size)+400000,'000000.00')  
              WHEN RTRIM(Size) LIKE N'%[0-9]H' AND ISNUMERIC(LEFT(Size,LEN(Size)-1))=1 THEN FORMAT(CONVERT(FLOAT,LEFT(Size,LEN(Size)-1)+'.5')+400000,'000000.00')  
              ELSE FORMAT(CHARINDEX(N'|'+LTRIM(RTRIM(Size))+N'|', @c_SizeList)+800000,'000000.00')  
         END +'-'+ Size  
   END  
  
  
   ----------  
   UPDATE a  
      SET Consigneekey    = b.Consigneekey  
        , Wavekey         = b.Wavekey  
        , PickslipNo      = b.PickslipNo  
        , DeliveryDate    = b.DeliveryDate  
        , BuyerPO         = b.BuyerPO  
        , B_Company       = b.B_Company  
        , B_Address       = b.B_Address  
        , C_Company       = b.C_Company  
        , C_Address       = b.C_Address  
        , B_Company_M3    = b.B_Company_M3  
        , B_Address_M3    = b.B_Address_M3  
        , C_Company_M3    = b.C_Company_M3  
        , C_Address_M3    = b.C_Address_M3  
        , Remark          = b.Remark  
        , Instruction     = b.Instruction     --MY  
        , InvoiceAmount   = b.InvoiceAmount  
     FROM #TEMP_PAKDT a  
     JOIN (  
        SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY DocKey ORDER BY Orderkey)  
          FROM #TEMP_PAKDT  
     ) b ON a.DocKey = b.DocKey AND b.SeqNo = 1  
  
  
  
   ----------  
   SELECT Storerkey          = UPPER( RTRIM( PAKDT.Storerkey ) )  
        , Company            = MAX( RTRIM( ST.Company ) )  
        , OrderGrouping      = ISNULL( RTRIM ( PAKDT.OrderGrouping ), '')  
        , DocKey             = ISNULL( RTRIM( PAKDT.DocKey ), '' )  
        , DocNumber          = MAX ( ISNULL( RTRIM ( PAKDT.DocNumber ), '') )  
        , ExternOrderKey     = MAX( RTRIM( PAKDT.ExternOrderKey ) )  
        , OrderKey           = MAX( RTRIM( PAKDT.OrderKey ) )  
        , ConsigneeKey       = MAX( RTRIM( PAKDT.ConsigneeKey ) )  
        , Wavekey            = MAX( RTRIM( PAKDT.Wavekey ) )  
        , Loadkey            = MAX( RTRIM( OH.Loadkey ) )  
        , PickSlipNo_Key     = ISNULL( RTRIM( PAKDT.PickSlipNo_Key ), '' )  
        , PickSlipNo         = MAX( ISNULL( RTRIM( PAKDT.PickSlipNo ), '' ) )  
        , DeliveryDate       = MAX( ISNULL( RTRIM( PAKDT.DeliveryDate ), '' ) )  
        , Type               = MAX( ISNULL( RTRIM( OH.Type ), '' ) )  
        , BuyerPO            = MAX( ISNULL( RTRIM( PAKDT.BuyerPO ), '' ) )  
        , ST_B_Company       = MAX( ISNULL( RTRIM( ST.B_Company ), '' ) )  
        , ST_B_Address1      = MAX( ISNULL( ST.B_Address1, '' ) )  
        , ST_B_Address2      = MAX( ISNULL( ST.B_Address2, '' ) )  
        , ST_B_Address3      = MAX( ISNULL( ST.B_Address3, '' ) )  
        , ST_B_Address4      = MAX( ISNULL( ST.B_Address4, '' ) )  
        , ST_B_City          = MAX( ISNULL( LTRIM(RTRIM( ST.B_City    )), '' ) )  
        , ST_B_State         = MAX( ISNULL( LTRIM(RTRIM( ST.B_State   )), '' ) )  
        , ST_B_Zip           = MAX( ISNULL( LTRIM(RTRIM( ST.B_Zip     )), '' ) )  
        , ST_B_Country       = MAX( ISNULL( LTRIM(RTRIM( ST.B_Country )), '' ) )  
        , ST_B_Phone1        = MAX( ISNULL( LTRIM(RTRIM( ST.B_Phone1  )), '' ) )  
        , ST_B_Contact1      = MAX( ISNULL( LTRIM(RTRIM( ST.B_Contact1)), '' ) )  
        , ST_B_Fax1          = MAX( ISNULL( LTRIM(RTRIM( ST.B_Fax1    )), '' ) )  
        , B_Company          = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN PAKDT.B_Company_M3 ELSE PAKDT.B_Company END, '') )  
        , B_Address1         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'',PAKDT.B_Address_M3,CX.B_Address1) ELSE IIF(@c_B_AddressExp<>'',PAKDT.B_Address,OH.B_Address1) END, '' ) )  
        , B_Address2         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'',''                ,CX.B_Address2) ELSE IIF(@c_B_AddressExp<>'',''             ,OH.B_Address2) END
, '' ) )  
        , B_Address3         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'',''                ,CX.B_Address3) ELSE IIF(@c_B_AddressExp<>'',''             ,OH.B_Address3) END
, '' ) )  
        , B_Address4         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'',''                ,CX.B_Address4) ELSE IIF(@c_B_AddressExp<>'',''             ,OH.B_Address4) END
, '' ) )  
        , B_City             = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'','',CX.B_City)     ELSE IIF(@c_B_AddressExp<>'','',OH.B_City)     END )), '' ) )  
        , B_State            = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'','',CX.B_State)    ELSE IIF(@c_B_AddressExp<>'','',OH.B_State)    END )), '' ) )  
        , B_Zip              = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'','',CX.B_Zip)      ELSE IIF(@c_B_AddressExp<>'','',OH.B_Zip)      END )), '' ) )  
        , B_Country          = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN IIF(@c_B_Address_M3Exp<>'','',CX.B_Country)  ELSE IIF(@c_B_AddressExp<>'','',OH.B_Country)  END )), '' ) )  
        , B_Phone1           = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN CX.B_Phone1   ELSE OH.B_Phone1   END )), '' ) )  
        , B_Contact1         = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN CX.B_Contact1 ELSE OH.B_Contact1 END )), '' ) )  
        , B_Fax1             = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderBAddressM3,%' THEN CX.B_Fax1     ELSE OH.B_Fax1     END )), '' ) )  
        , C_Company          = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN PAKDT.C_Company_M3 ELSE PAKDT.C_Company END, '') )  
        , C_Address1         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'',PAKDT.C_Address_M3,CX.Address1)   ELSE IIF(@c_C_AddressExp<>'',PAKDT.C_Address,OH.C_Address1) END
, '' ) )  
        , C_Address2         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'',''                ,CX.Address2)   ELSE IIF(@c_C_AddressExp<>'',''             ,OH.C_Address2) END
, '' ) )  
        , C_Address3         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'',''                ,CX.Address3)   ELSE IIF(@c_C_AddressExp<>'',''             ,OH.C_Address3) END
, '' ) )  
        , C_Address4         = MAX( ISNULL( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'',''                ,CX.Address4)   ELSE IIF(@c_C_AddressExp<>'',''             ,OH.C_Address4) END
, '' ) )  
        , C_City             = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'','',CX.City)       ELSE IIF(@c_C_AddressExp<>'','',OH.C_City)     END )), '' ) )  
        , C_State            = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'','',CX.State)      ELSE IIF(@c_C_AddressExp<>'','',OH.C_State)    END )), '' ) )  
        , C_Zip              = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'','',CX.Zip)        ELSE IIF(@c_C_AddressExp<>'','',OH.C_Zip)      END )), '' ) )  
        , C_Country          = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN IIF(@c_C_Address_M3Exp<>'','',CX.Country)    ELSE IIF(@c_C_AddressExp<>'','',OH.C_Country)  END )), '' ) )  
        , C_Phone1           = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN CX.Phone1   ELSE OH.C_Phone1   END )), '' ) )  
        , C_Contact1         = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN CX.Contact1 ELSE OH.C_Contact1 END )), '' ) )  
        , C_Fax1             = MAX( ISNULL( LTRIM(RTRIM( CASE WHEN @as_docmode='3' AND RptCfg.ShowFields NOT LIKE '%,UseOrderCAddressM3,%' THEN CX.Fax1     ELSE OH.C_Fax1     END )), '' ) )  
        , Remark             = MAX( ISNULL( RTRIM( PAKDT.Remark ), '' ) )  
        , Instruction        = MAX( ISNULL( RTRIM( PAKDT.Instruction ), '' ) )    --MY  
        , InvoiceAmount      = MAX( ISNULL( RTRIM( PAKDT.InvoiceAmount ), '' ) )  
        , CartonSort         = MAX( ISNULL( RTRIM( PAKDT.CartonSort ), '' ) )  
        , CartonNo           = PAKDT.CartonNo  
        , Labelno            = ISNULL( RTRIM( PAKDT.LabelNo ), '' )  
        , CartonWeight       = MAX( PAKDT.CartonWeight )  
        , CartonCBM          = MAX( PAKDT.CartonCBM )  
        , Dimenson           = MAX( PAKDT.Dimenson )  
        , LineGrouping       = ISNULL( RTRIM ( PAKDT.LineGrouping ), '')  
        , LineSort           = MAX( ISNULL( RTRIM ( PAKDT.LineSort ), '') )  
        , Line_No            = ROW_NUMBER() OVER(PARTITION BY PAKDT.DocKey, PAKDT.CartonNo, PAKDT.LabelNo  
                               ORDER BY MAX(PAKDT.CartonSort), PAKDT.LineGrouping,  
                                        MAX(PAKDT.LineSort), MAX(PAKDT.Style), MAX(PAKDT.Color), MAX(PAKDT.SizeSeq), MAX(PAKDT.Size), PAKDT.Sku )  
        , Refno              = MAX( ISNULL( RTRIM( PAKDT.Refno ), '' ) )  
        , Refno2             = MAX( ISNULL( RTRIM( PAKDT.Refno2 ), '' ) )  
        , Carton_Type        = MAX( RTRIM( PI.CartonType ) )  
        , Carton_Descr       = MAX( RTRIM( CT.CartonDescription ) )  
        , Carton_Weight      = MAX( PI.Weight )  
        , Carton_NetWeight   = MAX( PI.Weight - CT.CartonWeigth )  
        , Carton_CBM         = MAX( PI.Cube )  
        , Carton_Length      = MAX( PI.Length )  
        , Carton_Width       = MAX( PI.Width )  
        , Carton_Height      = MAX( PI.Height )  
        , Total_Weight       = MAX( PI_TTL.Total_Weight )  
        , Total_NetWeight    = MAX( PI_TTL.Total_NetWeight )  
        , Total_CBM          = MAX( PI_TTL.Total_CBM )  
        , Total_Carton       = MAX( PD_TTL.Total_Carton )  
        , Style              = MAX( ISNULL( RTRIM( PAKDT.Style ), '' ) )  
        , Color              = MAX( ISNULL( RTRIM( PAKDT.Color ), '' ) )  
        , Measurement        = MAX( ISNULL( RTRIM( PAKDT.Measurement ), '' ) )  
        , Size               = MAX( ISNULL( RTRIM( PAKDT.Size ), '' ) )  
        , SizeSeq            = MAX( PAKDT.SizeSeq )  
        , SKU                = ISNULL( RTRIM( PAKDT.Sku ), '' )  
        , Brand              = CAST(STUFF((SELECT DISTINCT ', ', RTRIM(Brand) FROM #TEMP_PAKDT WHERE FirstOrderkey=PAKDT.FirstOrderkey AND Brand<>''  
                                  ORDER BY 2 FOR XML PATH('')), 1, 2, '') AS NVARCHAR(500))  
        , Dept               = MAX( ISNULL( RTRIM( PAKDT.Dept ), '' ) )  
        , DESCR              = MAX( ISNULL( RTRIM( PAKDT.Descr ), '' ) )  
        , Qty                = SUM(PAKDT.Qty)  
        , UOM                = MAX( RTRIM( PAKDT.UOM ) )  
        , CBM                = SUM(PAKDT.Qty * PAKDT.StdCube)  
        , QtyPCE             = SUM(case when PAKDT.PrePackIndicator='Y' and PAKDT.Measurement like '[0-9][0-9]%' then convert(int,left(PAKDT.Measurement,2)) * PAKDT.Qty else PAKDT.Qty end)  
        , LineRef            = MAX( ISNULL( RTRIM( PAKDT.LineRef ), '' ) )  
        , LineRef2           = MAX( ISNULL( RTRIM( PAKDT.LineRef2 ), '' ) )  
        , LineRef3           = MAX( ISNULL( RTRIM( PAKDT.LineRef3 ), '' ) )  
        , LineRemark         = MAX( ISNULL( RTRIM( PAKDT.LineRemark ), '' ) )  
        , Storer_Logo        = MAX( RTRIM( CASE WHEN RL.Notes<>'' THEN RL.Notes ELSE ST.Logo END) )  
        , ShowFields         = MAX( RptCfg.ShowFields )  
        , SortOrderkey       = CASE WHEN @as_sortbyinputseq='Y' AND ISNULL(@c_OrderGroupingExp,'')='' THEN '' ELSE RTRIM(PAKDT.Storerkey)+'|'+ISNULL( RTRIM( PAKDT.DocKey ), '' ) END  
        , SeqPS              = MAX( ISNULL( SelPS.SeqNo, 0 ) )  
        , SeqEOK             = MAX( ISNULL( SelEOK.SeqNo, 0 ) )  
        , SeqOK              = MAX( ISNULL( SelOK.SeqNo, 0 ) )  
        , DocMode            = UPPER(LTRIM(RTRIM(ISNULL(@as_docmode,''))))   -- 1=Packing List, 2=Invoice, 3=Packing List for Exporter  
        , UnitPrice          = MAX( ISNULL( PAKDT.UnitPrice, 0 ) )  
        , ConsolPick         = MAX( ISNULL( RTRIM( PAKDT.ConsolPick ), '' ) )  
  
        , Lbl_ExternOrderkey = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ExternOrderkey') ) AS NVARCHAR(500))  
        , Lbl_DocNumber      = CAST( RTRIM( (select top 1 b.ColValue  
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocNumber') ) AS NVARCHAR(500))  
        , Lbl_Orderkey       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Orderkey') ) AS NVARCHAR(500))  
        , Lbl_ConsigneeKey   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ConsigneeKey') ) AS NVARCHAR(500))  
        , Lbl_Wavekey        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Wavekey') ) AS NVARCHAR(500))  
        , Lbl_PickslipNo     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PickslipNo') ) AS NVARCHAR(500))  
        , Lbl_DeliveryDate   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate') ) AS NVARCHAR(500))  
        , Lbl_BuyerPO        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BuyerPO') ) AS NVARCHAR(500))  
        , Lbl_Brand          = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Brand') ) AS NVARCHAR(500))  
        , Lbl_BillTo         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BillTo') ) AS NVARCHAR(500))  
        , Lbl_B_Phone        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_B_Phone') ) AS NVARCHAR(500))  
        , Lbl_ShipTo         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo') ) AS NVARCHAR(500))  
        , Lbl_C_Phone        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_C_Phone') ) AS NVARCHAR(500))  
        , Lbl_Remark         = CAST( RTRIM( (select top 1 b.ColValue  
       from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Remark') ) AS NVARCHAR(500))  
        , Lbl_Instruction    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Instruction') ) AS NVARCHAR(500))     --MY  
        , Lbl_PO_No          = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PO_No') ) AS NVARCHAR(500))  
        , Lbl_Total_CBM      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Total_CBM') ) AS NVARCHAR(500))  
        , Lbl_Total_Weight   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Total_Weight') ) AS NVARCHAR(500))  
        , Lbl_InvoiceAmount  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceAmount') ) AS NVARCHAR(500))  
        , Lbl_WeightUnit     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_WeightUnit') ) AS NVARCHAR(500))  
        , Lbl_OriginalUCC    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OriginalUCC') ) AS NVARCHAR(500))  
        , Lbl_Carton_CBM     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Carton_CBM') ) AS NVARCHAR(500))  
        , Lbl_Carton_Weight  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Carton_Weight') ) AS NVARCHAR(500))  
        , Lbl_Dimension      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Dimension') ) AS NVARCHAR(500))  
        , Lbl_LineNo         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_LineNo') ) AS NVARCHAR(500))  
        , Lbl_Style          = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Style') ) AS NVARCHAR(500))  
        , Lbl_Color          = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Color') ) AS NVARCHAR(500))  
        , Lbl_Size           = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Size') ) AS NVARCHAR(500))  
        , Lbl_Sku            = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Sku') ) AS NVARCHAR(500))  
        , Lbl_Dept           = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Dept') ) AS NVARCHAR(500))  
        , Lbl_Descr          = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Descr') ) AS NVARCHAR(500))  
        , Lbl_UnitPrice      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_UnitPrice') ) AS NVARCHAR(500))  
        , Lbl_UnitPriceFormat= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_UnitPriceFormat') ) AS NVARCHAR(500))  
        , Lbl_Qty            = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Qty') ) AS NVARCHAR(500))  
        , Lbl_UOM            = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_UOM') ) AS NVARCHAR(500))  
        , Lbl_TotalPCE       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_TotalPCE') ) AS NVARCHAR(500))  
        , Lbl_LineRef        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef') ) AS NVARCHAR(500))  
        , Lbl_LineRef2       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef2') ) AS NVARCHAR(500))  
        , Lbl_LineRef3       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef3') ) AS NVARCHAR(500))  
        , Lbl_LineRemark     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_LineRemark') ) AS NVARCHAR(500))  
        , Lbl_InvAmtCurrency = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InvAmtCurrency') ) AS NVARCHAR(500))  
        , Lbl_Wavekey_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Wavekey_M3') ) AS NVARCHAR(500))  
        , Lbl_PickslipNo_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PickslipNo_M3') ) AS NVARCHAR(500))  
        , Lbl_DeliveryDate_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate_M3') ) AS NVARCHAR(500))  
        , Lbl_BuyerPO_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BuyerPO_M3') ) AS NVARCHAR(500))  
        , Lbl_Brand_M3       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Brand_M3') ) AS NVARCHAR(500))  
        , Lbl_BillTo_M3      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BillTo_M3') ) AS NVARCHAR(500))  
        , Lbl_B_Phone_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_B_Phone_M3') ) AS NVARCHAR(500))  
        , Lbl_ShipTo_M3      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo_M3') ) AS NVARCHAR(500))  
        , Lbl_C_Phone_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_C_Phone_M3') ) AS NVARCHAR(500))  
        , Lbl_PO_No_M3       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PO_No_M3') ) AS NVARCHAR(500))  
        , Lbl_Total_CBM_M3   =CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Total_CBM_M3') ) AS NVARCHAR(500))  
        , Lbl_Total_Weight_M3=CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Total_Weight_M3') ) AS NVARCHAR(500))  
        , Lbl_InvoiceAmount_M3=CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceAmount_M3') ) AS NVARCHAR(500))  
        , Lbl_OriginalUCC_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OriginalUCC_M3') ) AS NVARCHAR(500))  
        , Lbl_Carton_CBM_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Carton_CBM_M3') ) AS NVARCHAR(500))  
        , Lbl_Carton_Weight_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Carton_Weight_M3') ) AS NVARCHAR(500))  
        , Lbl_Dimension_M3   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Dimension_M3') ) AS NVARCHAR(500))  
        , Exporter           = ISNULL(RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Exporter') ), '')  
        , ReportHeading      = CASE WHEN MAX(PAKDT.ReportHeading)<>'' THEN RTRIM(MAX(PAKDT.ReportHeading)) ELSE  
                               CAST( RTRIM( (select top 1 b.ColValue  
                               from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ReportHeading') ) AS NVARCHAR(500)) END  
        , ReportTitle        = CASE WHEN MAX(PAKDT.ReportTitle)<>'' THEN RTRIM(MAX(PAKDT.ReportTitle)) ELSE  
                               CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ReportTitle') ) AS NVARCHAR(500)) END  
        , ReportTitle_M2     = CASE WHEN MAX(PAKDT.ReportTitle_M2)<>'' THEN RTRIM(MAX(PAKDT.ReportTitle_M2)) ELSE  
                               CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ReportTitle_M2') ) AS NVARCHAR(500)) END  
        , ReportTitle_M3     = CASE WHEN MAX(PAKDT.ReportTitle_M3)<>'' THEN RTRIM(MAX(PAKDT.ReportTitle_M3)) ELSE  
                               CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ReportTitle_M3') ) AS NVARCHAR(500)) END  
        , Lbl_OrderGroupTitle= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OrderGroupTitle') ) AS NVARCHAR(500))  
        , Lbl_OrderGroupTotalCarton= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OrderGroupTotalCarton') ) AS NVARCHAR(500))  
        , Lbl_OrderGroupTotalQty= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OrderGroupTotalQty') ) AS NVARCHAR(500))  
        , Lbl_OrderGroupTotalWeight= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OrderGroupTotalWeight') ) AS NVARCHAR(500))  
        , Lbl_OrderGroupTotalCBM= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_OrderGroupTotalCBM') ) AS NVARCHAR(500))  
        , N_Xpos1            = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos1') ) AS NVARCHAR(50))  
        , N_Xpos2            = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos2') ) AS NVARCHAR(50))  
        , N_Xpos_Remark      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Remark') ) AS NVARCHAR(50))  
        , N_Xpos_T_BillTo    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_BillTo') ) AS NVARCHAR(50))  
        , N_Xpos_BillTo      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_BillTo') ) AS NVARCHAR(50))  
        , N_Xpos_T_B_Phone   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_B_Phone') ) AS NVARCHAR(50))  
        , N_Xpos_B_Phone     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_B_Phone') ) AS NVARCHAR(50))  
        , N_Xpos_T_ShipTo    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_ShipTo') ) AS NVARCHAR(50))  
        , N_Xpos_ShipTo      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_ShipTo') ) AS NVARCHAR(50))  
        , N_Xpos_T_C_Phone   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_C_Phone') ) AS NVARCHAR(50))  
        , N_Xpos_C_Phone     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_C_Phone') ) AS NVARCHAR(50))  
        , N_Xpos_LabelNo     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LabelNo') ) AS NVARCHAR(50))  
        , N_Xpos_OriginalUCC = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_OriginalUCC') ) AS NVARCHAR(50))  
        , N_Xpos_CartonWeight= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_CartonWeight') ) AS NVARCHAR(50))  
        , N_Xpos_CartonCBM   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_CartonCBM') ) AS NVARCHAR(50))  
        , N_Xpos_Dimension   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Dimension') ) AS NVARCHAR(50))  
        , N_Xpos_LineNo      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineNo') ) AS NVARCHAR(50))  
        , N_Xpos_Style       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Style') ) AS NVARCHAR(50))  
        , N_Xpos_Color       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Color') ) AS NVARCHAR(50))  
        , N_Xpos_Size        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Size') ) AS NVARCHAR(50))  
        , N_Xpos_Sku         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Sku') ) AS NVARCHAR(50))  
        , N_Xpos_Dept        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Dept') ) AS NVARCHAR(50))  
        , N_Xpos_Descr       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Descr') ) AS NVARCHAR(50))  
        , N_Xpos_UnitPrice   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UnitPrice') ) AS NVARCHAR(50))  
        , N_Xpos_Qty         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Qty') ) AS NVARCHAR(50))  
        , N_Xpos_UOM         = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UOM') ) AS NVARCHAR(50))  
        , N_Xpos_TotalPCE    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TotalPCE') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef2    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef2') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef3    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef3') ) AS NVARCHAR(50))  
        , N_Xpos_LineRemark  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRemark') ) AS NVARCHAR(50))  
        , N_Xpos_T_BillTo_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_BillTo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_BillTo_M3   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_BillTo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_T_B_Phone_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_B_Phone_M3') ) AS NVARCHAR(50))  
        , N_Xpos_B_Phone_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_B_Phone_M3') ) AS NVARCHAR(50))  
        , N_Xpos_T_ShipTo_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_ShipTo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_ShipTo_M3   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_ShipTo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_T_C_Phone_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_T_C_Phone_M3') ) AS NVARCHAR(50))  
        , N_Xpos_C_Phone_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_C_Phone_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LabelNo_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LabelNo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_OriginalUCC_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_OriginalUCC_M3') ) AS NVARCHAR(50))  
        , N_Xpos_CartonWeight_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_CartonWeight_M3') ) AS NVARCHAR(50))  
        , N_Xpos_CartonCBM_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_CartonCBM_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Dimension_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Dimension_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LineNo_M3   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineNo_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Style_M3    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Style_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Color_M3    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Color_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Size_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Size_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Sku_M3      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Sku_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Dept_M3     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Dept_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Descr_M3    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Descr_M3') ) AS NVARCHAR(50))  
        , N_Xpos_UnitPrice_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UnitPrice_M3') ) AS NVARCHAR(50))  
        , N_Xpos_Qty_M3      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Qty_M3') ) AS NVARCHAR(50))  
        , N_Xpos_UOM_M3      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UOM_M3') ) AS NVARCHAR(50))  
        , N_Xpos_TotalPCE_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TotalPCE_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef_M3  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef2_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef2_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LineRef3_M3 = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef3_M3') ) AS NVARCHAR(50))  
        , N_Xpos_LineRemark_M3= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRemark_M3') ) AS NVARCHAR(50))  
        , N_Width_T_BillTo   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_BillTo') ) AS NVARCHAR(50))  
        , N_Width_BillTo     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_BillTo') ) AS NVARCHAR(50))  
        , N_Width_T_B_Phone  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_B_Phone') ) AS NVARCHAR(50))  
        , N_Width_B_Phone    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_B_Phone') ) AS NVARCHAR(50))  
        , N_Width_T_ShipTo   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_ShipTo') ) AS NVARCHAR(50))  
        , N_Width_ShipTo     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_ShipTo') ) AS NVARCHAR(50))  
        , N_Width_T_C_Phone  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_C_Phone') ) AS NVARCHAR(50))  
        , N_Width_C_Phone    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_C_Phone') ) AS NVARCHAR(50))  
        , N_Width_Remark     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Remark') ) AS NVARCHAR(50))  
        , N_Width_T_LabelNo  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_LabelNo') ) AS NVARCHAR(50))  
        , N_Width_T_OriginalUCC= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_OriginalUCC') ) AS NVARCHAR(50))  
        , N_Width_T_CartonWeight= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_CartonWeight') ) AS NVARCHAR(50))  
        , N_Width_T_CartonCBM= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_CartonCBM') ) AS NVARCHAR(50))  
        , N_Width_T_Dimension= CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_T_Dimension') ) AS NVARCHAR(50))  
        , N_Width_LineNo     = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineNo') ) AS NVARCHAR(50))  
        , N_Width_Style      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Style') ) AS NVARCHAR(50))  
        , N_Width_Color      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Color') ) AS NVARCHAR(50))  
        , N_Width_Size       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Size') ) AS NVARCHAR(50))  
        , N_Width_Sku        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Sku') ) AS NVARCHAR(50))  
        , N_Width_Dept       = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Dept') ) AS NVARCHAR(50))  
        , N_Width_Descr      = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Descr') ) AS NVARCHAR(50))  
        , N_Width_UnitPrice  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_UnitPrice') ) AS NVARCHAR(50))  
        , N_Width_Qty        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Qty') ) AS NVARCHAR(50))  
        , N_Width_UOM        = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_UOM') ) AS NVARCHAR(50))  
        , N_Width_TotalPCE   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TotalPCE') ) AS NVARCHAR(50))  
        , N_Width_LineRef    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef') ) AS NVARCHAR(50))  
        , N_Width_LineRef2   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef2') ) AS NVARCHAR(50))  
        , N_Width_LineRef3   = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef3') ) AS NVARCHAR(50))  
        , N_Width_LineRemark = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRemark') ) AS NVARCHAR(50))  
        , N_Height_BillTo    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Height_BillTo') ) AS NVARCHAR(50))  
        , N_Height_ShipTo    = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Height_ShipTo') ) AS NVARCHAR(50))  
        , datawindow         = @c_DataWidnow  
        , OrderLineSeqNo     = ROW_NUMBER() OVER(PARTITION BY PAKDT.DocKey ORDER BY MAX(PAKDT.CartonSort), PAKDT.CartonNo,  
                               PAKDT.LineGrouping, MAX(PAKDT.LineSort), MAX(PAKDT.Style), MAX(PAKDT.Color), MAX(PAKDT.SizeSeq), MAX(PAKDT.Size) )  
        , Barcode            = MAX ( ISNULL( RTRIM ( PAKDT.Barcode ), '') )  
        , Lbl_CartonLabelNo  = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CartonLabelNo') ) AS NVARCHAR(500))  
        , Lbl_CartonLabelNo_M3=CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CartonLabelNo_M3') ) AS NVARCHAR(500))  
        , Lbl_TotalCtnQty    = CAST( RTRIM( (select top 1 b.ColValue  
                  from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_TotalCtnQty') ) AS NVARCHAR(500))  
        , Lbl_ExtOrdKey_Summary = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ExtOrdKey_Summary') ) AS NVARCHAR(500))  
        , N_Width_ExtOrdKey_Summary = CAST( RTRIM( (select top 1 b.ColValue  
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b  
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_Width_ExtOrdKey_Summary') ) AS NVARCHAR(50))  
        , ExtOrdKey01        = MAX ( ISNULL( PAKDT.ExtOrdKey01, '' ) )  
        , ExtOrdKey02        = MAX ( ISNULL( PAKDT.ExtOrdKey02, '' ) )  
        , ExtOrdKey03        = MAX ( ISNULL( PAKDT.ExtOrdKey03, '' ) )  
        , ExtOrdKey04        = MAX ( ISNULL( PAKDT.ExtOrdKey04, '' ) )  
        , ExtOrdKey05        = MAX ( ISNULL( PAKDT.ExtOrdKey05, '' ) )  
        , Section            = ISNULL( PAKDT.Section, '' )  
        , SplitPrintKey      = MAX ( ISNULL( RTRIM ( PAKDT.SplitPrintKey ), '') )  
        , CtnGrouping        = ISNULL( RTRIM ( PAKDT.CtnGrouping ), '')  
        , ISNULL(OH.ROUTE,'') AS [Route]  
        , ISNULL(OH.InvoiceNo,'') AS InvoiceNo  
        , ISNULL(CLK.SHORT,'N') AS ShowPrice  
        , UPCCode            = MAX ( ISNULL( PAKDT.UPCCode, '' ) )   --WL02  
           
  
  
   FROM #TEMP_PAKDT PAKDT  
   JOIN dbo.ORDERS OH (NOLOCK) ON PAKDT.FirstOrderKey=OH.OrderKey  
   JOIN dbo.STORER ST (NOLOCK) ON OH.StorerKey=ST.StorerKey  
  
   LEFT JOIN dbo.CODELKUP RL (NOLOCK) ON (RL.Listname = 'RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = PAKDT.Storerkey AND RL.Long = @c_DataWidnow)  
   LEFT JOIN dbo.STORER CX (NOLOCK) ON CX.Storerkey='PL-'+RTRIM(OH.Storerkey)+'-'+ ISNULL(OH.C_Country,'')  
   LEFT JOIN dbo.PackInfo PI (NOLOCK) ON PAKDT.PickSlipNo_Key=PI.PickSlipNo AND PAKDT.CartonNo=PI.CartonNo  
   LEFT JOIN (  
      SELECT CartonType        = CartonType  
           , CartonDescription = MAX(CartonDescription)  
           , Cube              = MAX(Cube)  
           , CartonWeigth      = MAX(CartonWeight)  
           , CartonLength      = MAX(CartonLength)  
           , CartonWidth       = MAX(CartonWidth)  
           , CartonHeight      = MAX(CartonHeight)  
      FROM dbo.CARTONIZATION (NOLOCK)  
      GROUP BY CartonType  
   ) CT ON PI.CartonType = CT.CartonType  
  
   LEFT JOIN (  
        SELECT a.PickSlipNo, Total_Weight=SUM(a.Weight), Total_CBM=SUM(a.Cube), Total_NetWeight=SUM(a.Weight - b.CartonWeight)  
          FROM dbo.PackInfo a(NOLOCK)  
          LEFT JOIN (SELECT CartonType, CartonWeight=MAX(CartonWeight) FROM dbo.CARTONIZATION (NOLOCK) GROUP BY CartonType) b  
            ON a.CartonType = b.CartonType  
         GROUP BY PickSlipNo  
   ) PI_TTL ON PAKDT.PickSlipNo_Key=PI_TTL.PickSlipNo  
  
   LEFT JOIN (  
        SELECT PickSlipNo, Total_Carton=COUNT(DISTINCT CartonNo)  
          FROM dbo.PackDetail (NOLOCK)  
         GROUP BY PickSlipNo  
   ) PD_TTL ON PAKDT.PickSlipNo_Key=PD_TTL.PickSlipNo  
  
   LEFT JOIN (  
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWidnow AND Short='Y'  
   ) RptCfg  
   ON RptCfg.Storerkey=PAKDT.Storerkey AND RptCfg.SeqNo=1  
  
   LEFT JOIN (  
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'  
   ) RptCfg2  
   ON RptCfg2.Storerkey=PAKDT.Storerkey AND RptCfg2.SeqNo=1  
  
   LEFT JOIN (  
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))  
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)  
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'  
   ) RptCfg3  
   ON RptCfg3.Storerkey=PAKDT.Storerkey AND RptCfg3.SeqNo=1  
  
   LEFT JOIN #TEMP_PICKSLIPNO     SelPS  ON PAKDT.PickSlipNo_Key = SelPS.ColValue  
   LEFT JOIN #TEMP_EXTERNORDERKEY SelEOK ON PAKDT.ExternOrderKey = SelEOK.ColValue  
   LEFT JOIN #TEMP_ORDERKEY       SelOK  ON PAKDT.Orderkey       = SelOK.ColValue  
     
   LEFT JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'REPORTCFG' AND CLK.STORERKEY = PAKDT.Storerkey AND CLK.LONG = @c_DataWidnow AND CLK.CODE = 'ShowPrice'  
  
   GROUP BY PAKDT.Storerkey  
          , PAKDT.OrderGrouping  
          , PAKDT.DocKey  
          , PAKDT.FirstOrderkey  
          , PAKDT.PickSlipNo_Key  
          , PAKDT.Section  
          , PAKDT.CtnGrouping  
          , PAKDT.CartonNo  
          , PAKDT.LabelNo  
          , PAKDT.LineGrouping  
          , PAKDT.SKU  
          , ISNULL(OH.ROUTE,'')  
          , ISNULL(OH.InvoiceNo,'')  
          , ISNULL(CLK.SHORT,'N')  
  
   ORDER BY SortOrderkey, SeqPS, SeqEOK, SeqOK, DocKey, Section, CartonNo, LabelNo, Line_No  
   --WL01 End  
  
END  
  

GO