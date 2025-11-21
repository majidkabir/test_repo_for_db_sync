SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*********************************************************************************/
/* Stored Procedure: isp_GSICartonLabel                                          */
/* Creation Date: 17-Mar-2008                                                    */
/* Copyright: IDS                                                                */
/* Written by: YokeBeen                                                          */
/*                                                                               */
/* Purpose:  SOS#101899 - GSI Carton Label printing for IDSUS.                   */
/*                                                                               */
/* Called By:  PB - RCM from Loadplan/Packing/MBOL Modules                       */
/*                                                                               */
/* PVCS Version: 1.24                                                            */
/*                                                                               */
/* Version: 5.4                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date           Author      Ver.  Purposes                                     */
/* 30-Sep-2008    Adrian      1.0   #1 - Changed Description pointing to         */
/*                                       actual item description -               */
/*                                       Style_Color_Size_Meas Field.            */
/*                                  #2 - Corrected Carrier Facility Mapping      */
/*                                       to NVARCHAR(10)                         */
/*                                  #3 - Extended from NVARCHAR(5) to NVARCHAR(20)*/
/*                                       to match the actual field length        */
/*                                  - (AAY001)                                   */
/* 01-Oct-2008    Adrian      1.0   #1 - Label is took directly from             */
/*                                       PACKDETAIL.LabelNo.                     */
/*                                  #2 - Changed "&" to "&" in order to          */
/*                                       handle the XML, limitation in all       */
/*                                       name/address fields. - (AAY002)         */
/* 03-Oct-2008    Adrian      1.0   If Markforkey is blank, get data from        */
/*                                  consigneekey. - (AAY003)                     */
/* 24-Oct-2008    Adrian      1.1   #1 Updated storerkey length from 7 to 8      */
/*                                  #2 - Changed "&" to "&" in order to          */
/*                                       handle the XML, limitation in from      */
/*                                       name  fields. - (AAY004)                */
/* 25-Oct-2008    Larry       1.1   #Add Facility.userdefine19 =Print server     */
/*                                  Path - (LAu001)                              */
/* 31-Oct-2008    YokeBeen    1.2   Performance Tuning. - (YokeBeen01)           */
/* 06-Nov-2008    Adrian      1.3   If single sku, retail sku is taken from      */
/*                                  orderdetail - (AAY005)                       */
/* 26-Nov-2008    Larry       1.4   Add orderdetail.userdefine09 =packtype       */
/*                                  single,prepack,bulkpack - (LAu002)           */
/* 26-Nov-2008    Adrian      1.4   Changed PackType to NVARCHAR(18) to match    */
/*                                  actual field - (AAY006)                      */
/*                                  Removed logic and extract direct from        */
/*                                  orderdetail09 - (AAY007)                     */
/*                                  Added field for prepack SKU size             */
/*                                  breakdown in orders.userdefine06             */
/*                                  Added field for prepack Qty                  */
/*                                  breakdown in orders.userdefine07             */
/*                                  Added field for prepack Retail               */
/*                                  description in orders.userdefine08           */
/*                                  - (AAY008)                                   */
/* 29-Jan-2009    Adrian      1.4   Added Consgineekey --(AAY009)                */
/* 10-Mar-2009    Shong       1.4   Performance Tuning  (SHONG20090310)          */
/* 28-Mar-2009    James       1.5   SOS127598 - RDT Scan & Pack. Change the      */
/*                                  result to be inserted into table             */
/*                                  GSICartonLabl_XML                            */
/* 01-Jun-2009    RickyYee    1.6   Change '&' to '&' in the Busr1               */
/*                                  field (RY20090601)                           */
/* 16-Jun-2009    TLTING      1.6   Performance  Tuning (tlting02)               */
/* 07-Jul-2009    Adrian      1.7   Added Retailer SKU Dept and SKU Product      */
/*                                  grouping. -- (AAY010)                        */
/*                                  Added MasterSKU mapping for Retailer         */
/*                                  -- (AAY011)                                  */
/*                                  Removed SKU.BUSR5 Export --(AAY012)          */
/*                                  Added Department Name on Order Header        */
/*                                  for retailer requirement --(AAY013)          */
/* 13-Jul-2009    Adrian      1.8   Moved SKU Dept and SKU Product mapping       */
/*                                  to not directly extract. --(AAY014)          */
/* 17-Jul-2009    Adrian      1.8   Added Printed by Field --(AAY015)            */
/*                                  Moved Season Code mapping and removed        */
/*                                  Carton Count numbering --(AAY016)            */
/* 13-Aug-2009    Adrian      1.9   Updated the Style_Description field          */
/*                                  length from 20 to 30 to match WMS.           */
/*                                  --AAY017                                     */
/*                                  Updated SKU Style and Color fields from      */
/*                                  15 to 20 and 8 to 10 --AAY0018               */
/*                                  Handle & issue in consigneekey,billtokey     */
/*                                  and markforkey --AAY0019                     */
/* 20-Aug-2009    NJOW01      1.9   SOS141877-Batch Print Label in LoadPlan.     */
/*                                  IF filename = TEMPDB, insert result to       */
/*                                  #TMP_GSICartonLabel_XML without return       */
/*                                  result. Tmp table is shared by               */
/*                                  isp_gsispooler                               */
/* 19-Oct-2009    NJOW02      1.10  SOS150721 - remove the MBOL validation       */
/* 07-Dec-2009    Adrian      1.11  AAY0020 - Added Retail SKU to all            */
/*                                  content labels.                              */
/* 19-Feb-2009    RickyYee    1.11  SOS161629 - Remove the temp Table index      */
/*                                  and include the primary key                  */
/* 27-Feb-2010    Vicky       1.12  Fix the NULL value of CartonType             */
/*                                  (Vicky01)                                    */
/* 01-Mar-2010    ChewKP      1.12  Pass in DropID as parameters and             */
/*                                  include DropID Filtering (ChewKP01)          */
/* 02-Mar-2010    ChewKP      1.13  Update condition (ChewKP02)                  */
/* 02-Mar-2010    Vicky       1.13  Add in NOLOCK (Vicky02)                      */
/* 01-Mar-2010    Adrian      1.13  Added Routing Date from MBOL Header          */
/*                                  userdefine07 --AAY0021                       */
/* 19-Apr-2010    Adrian      1.13  Added Order product group to Order           */
/*                                  Header --AAY0022                             */
/* 03-May-2010    KW01        1.14  For BBB.btw zip removed hyphen               */
/*                                  in zipcode(temporary) --kw01                 */
/* 17-May-2010    Adrian      1.14  Reversed KW changes. AAY0023 #1              */
/*                                  Removed NVARCHAR(5) restriction on field 41  */
/*                                  --AAY0023 #2                                 */
/*                                  Added UPS Requirement -- AAY0023 #3          */
/*                                  As part of the UPS requirement for pick      */
/*                                  up date, this date will be the current       */
/*                                  date if the field is blank. --AAY0023 #4     */
/*                                  Julian Day of Pick UP UPS --AAY0023 #5       */
/*                                  Added UCC# to the XML Header --AAY024        */
/* 08-Jul-2010    Larry       1.14  Post SSCC# as JobName. LAu0003               */
/* 16-Aug-2010    NJOW03      1.15  184305-add a config key 'GetPackWeight'      */
/*                                  to update weight(field60) from the           */
/*                                  packheader.TotCtnWeight else                 */
/*                                  sku.stdgrosswgt                              */
/* 02-Sep-2010    AQSKC       1.16  Remove reference to RDT db                   */
/* 21-Oct-2010    Adrian      1.17  SOS# 193703 - Add "Distinct"(Adrian)         */
/* 26-Jan-2011    Leong       1.18  SOS# 199159 - Use function for XML           */
/*                                                standard conversion            */
/* 11-Mar-2011    NJOW04      1.19  Add label no param cater for multi           */
/*                                  packing/pickslip per order                   */
/* 19-Apr-2011    Adrian      1.20  Increaseed Consignee SKU field NVARCHAR(20)  */
/*                                  Order_Session map to MBOL.BoookingRef        */
/*                                  for Routing.                                 */
/*                                  Duplicate_label_Message map to Orders        */
/*                                  Userdefine01 (for JCP Load ID)               */
/*                                  --AAY025                                     */
/* 08-Jun-2011    NJOW05      1.21  216881-include new fields and to handle      */
/*                                  retailer component SKUs                      */
/* 15-Sep-2011    NJOW06      1.22  Performance tuning                           */
/* 06-Oct-2011    Adrian      1.23  SOS# 227399 - If the Mark for fields are     */
/*                                  blank, get from the ship to fields           */
/* 16-Nov-2011    MCTang      1.24  SOS227224 - Consolidate OrderKey (MC01)      */
/* 01-Dec-2011    MCTang      1.24  SOS 225917 (MC02)                            */
/* 05-Dec-2011    NJOW07      1.25  231818-Bartender GSI Script output as CSV    */
/*                                  format                                       */
/* 04-Jan-2012    MCTang      1.26  Fix ConsoOrderKey with multiple orders, only */
/*                                  output 1 order's content                     */
/* 10-01-2012     ChewKP      1.27  Standardize ConsoOrderKey Mapping            */
/*                                  (ChewKP03)                                   */
/* 11-01-2012     ChewKP      1.28  CSV Parameters changes (ChewKP04)            */
/* 12-02-2012     NJOW08      1.29  Put surffix -CONS to externorderkey if Conso */
/* 19-01-2012     NJOW09      1.30  233853-Map new fields for FedEx Label        */
/* 23-01-2012     SHONG01     1.31  Bug Fixing                                   */
/* 23-01-2012     ADRIAN      1.32  ISNULL(PACKHEADER.TTLCnts,0) --AAY026        */
/* 05-03-2012     SHONG       1.33  Remove temporary and field lookup table      */
/* 05-03-2012     SHONG       1.34  Bug Fixing for Components Qty                */
/* 29-02-2012     ChewKP      1.35  Different Calculation on Master Pack cartons */
/*                                  (ChewKP05)                                   */
/* 12-03-2012     Ting        1.36  Performance Tuning (tlting03)                */
/* 06-07-2012     NJOW10      1.37  247983-Change Mapping on GS1 script to show  */
/*                                  prepack and component information            */
/* 22-09-2012     Larry       1.37  SOS# 256897 - fix for incorrect carton No.   */
/* 11-02-2014     YTWan       1.38  SOS#302522-System Generate sortation code.   */
/*                                  (Wan01)                                      */
/* 13-02-2014     YTWan       1.39  SOS#302678-Change GS1 mapping for gap label  */
/*                                  (Wan02)                                      */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/*********************************************************************************/

CREATE PROC [dbo].[isp_GSICartonLabel] (
     @c_MBOLKey       NVARCHAR(10)     = ''
   , @c_OrderKey      NVARCHAR(10)     = ''
   , @c_TemplateID    NVARCHAR(60)  = ''
   , @c_PrinterID     NVARCHAR(215) = ''
   , @c_FileName      NVARCHAR(215) = ''
   , @c_CartonNoParm  NVARCHAR(5)   = ''
   , @c_DropID        NVARCHAR(20)  = ''
   , @c_LabelNoParm   NVARCHAR(20)  = ''  --NJOW04
   , @c_ConsoOrderKey NVARCHAR(30)  = '') --MC01
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @b_debug Int

   IF @c_TemplateID = 'AAA'
   BEGIN
      SET @b_debug = 2
   END
   Else
   BEGIN
      SET @b_debug = 0
   END

/*********************************************/
/* Variables Declaration (Start)             */
/*********************************************/

   DECLARE @n_StartTCnt  Int
   SELECT  @n_StartTCnt = @@TRANCOUNT

   DECLARE @n_continue      Int
         , @c_errmsg         NVARCHAR(255)
         , @b_success        Int
         , @n_err            Int
         , @c_ExecStatements NVarChar(4000)
         , @c_ExecArguments  NVarChar(4000)

   -- Extract from MBOL/Orders/PackInfo/Sku/PackDetail table

   DECLARE @c_ExternOrderKey NVARCHAR(50)  --tlting_ext
         , @c_BuyerPO        NVARCHAR(20)
         , @c_StorerKey      NVARCHAR(15)
         , @c_Notes2         NVARCHAR(255)

   DECLARE @c_Style          NVARCHAR(20)
         , @c_Color          NVARCHAR(10)
         , @c_Measurement    NVARCHAR(5)
         , @c_Size  NVARCHAR(5)
         , @c_RSku           NVARCHAR(20) --AAY0020
         , @c_Sku            NVARCHAR(20)
         , @c_SkuDescr       NVARCHAR(60)
         , @c_RetailSku    NVARCHAR(20)
         , @c_SKUBUSR8       NVARCHAR(30)
         , @n_ComponentQty   Int

   DECLARE @c_CompStyle       NVARCHAR(20) --Njow05
         , @c_CompColor       NVARCHAR(10)
         , @c_CompMeasurement NVARCHAR(5)
         , @c_CompSize        NVARCHAR(5)
         , @c_Apply_OrderDetailRef NVARCHAR(1)
         , @c_Pack_qty        NVARCHAR(5)  --AAY20120217
         , @c_ParentSku       NVARCHAR(20) --NJOW10
         , @c_PrevParentSku   NVARCHAR(20) --NJOW10

   --NJOW05
   DECLARE @c_RetailComponentSKU NVARCHAR(20)
         , @c_RetailComponentQty NVARCHAR(5)
         , @n_StartFieldID   Int
         , @n_TotalCartonQty Int
         , @n_MaxLineNo      Int
         , @n_GetFieldValStart   Int
         , @n_ColumnIdx          INT

   DECLARE @c_CartonNo       NVARCHAR(10)
         , @n_SkuCnt         Int
         , @n_TotQty         Int
         , @n_TotSkuQty      Int
         , @c_SingleSku      NVARCHAR(20)
         , @n_CtnByMbol      Int
         , @c_PkInCnt        NVARCHAR(18) --LAu001
         , @c_PkSzScl        NVARCHAR(18) --AAY008
         , @c_PkQtyScl       NVARCHAR(18) --AAY008
         , @c_PkDesc         NVARCHAR(18) --AAY008
         , @c_MstrSKU        NVARCHAR(20) --AAY011
         , @c_LabelNo        NVARCHAR(20) --LAu0003

--NJOW03
   DECLARE @c_busr7          NVARCHAR(30)
         , @c_contentdesc    NVARCHAR(30)
         , @n_precartonno    Int
         , @n_curcartonno    Int
         , @c_facility       NVARCHAR(5)
         , @c_getpackweight  NVARCHAR(1)
         , @c_czip           NVARCHAR(18)
         , @c_dischargeplace NVARCHAR(30)
         , @c_RouteCode      NVARCHAR(20)
         , @c_Address        NVARCHAR(25)
         , @c_City           NVARCHAR(25)
         , @c_State  NVARCHAR(10)
         , @c_Zip            NVARCHAR(10)

   -- Extract from General
   DECLARE @c_Date           NVARCHAR(8)
         , @c_Time           NVARCHAR(8)
         , @c_DateTime       NVARCHAR(14)
         , @n_SeqNo          Int
         , @n_SeqLineNo      Int
         , @n_licnt          Int
         , @c_licnt          NVARCHAR(2)
         , @n_PageNumber     Int
         , @n_CartonNoParm   Int
         , @n_CartonLineItems INT
     -- SOS127598

   -- (ChewKP05)
   DECLARE
           @c_PickSlipNo NVARCHAR(10)
         , @n_TTLCnts   INT
         , @n_CartonNo  INT
         , @c_MasterTemplateID NVARCHAR(60)
         , @c_MasterPack NVARCHAR(1)
      , @c_ColValue NVARCHAR(60)



   DECLARE @c_FullLineText   NVARCHAR(MAX) --NJOW07
   DECLARE @c_CartonLine1    NVARCHAR(MAX)
   DECLARE @c_CartonLine2    NVARCHAR(MAX)

   --(Wan01) - START
   DECLARE @c_SortKeyName    NVARCHAR(30)
         , @c_SortCode       NVARCHAR(30)
         , @c_GenSortCodeSP  NVARCHAR(100)
  
         , @c_SQL            NVARCHAR(MAX)      
         , @c_SQLParm        NVARCHAR(MAX)

         , @n_TotalCartonUnitQty INT         --(Wan02)  

   SET @c_SortKeyName  = ''
   SET @c_SortCode     = ''
   SET @c_GenSortCodeSP= ''
   SET @c_SQL          = ''
   SET @c_SQLParm      = ''

   SET @n_TotalCartonUnitQty  = 0            --(Wan02)
   --(Wan01) - END

   SET @c_FullLineText = ''
   SET @c_CartonLine1  = ''
   SET @c_CartonLine2  = ''
   SET @n_CartonLineItems = 0

   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   -- Variables Initialization
   SET @c_ExecStatements = ''
   SET @c_ExecArguments  = ''
   SET @n_continue       = 0
   SET @c_errmsg         = ''
   SET @b_success        = 0
   SET @n_err            = 0
   SET @c_ExternOrderKey = ''
   SET @c_BuyerPO        = ''
   SET @c_StorerKey      = ''
   SET @c_Notes2         = ''
   SET @c_CartonNo       = ''
   SET @c_Date           = ''
   SET @c_Time           = ''
   SET @n_SeqNo          = 0
   SET @n_SeqLineNo      = 0
   SET @c_licnt          = ''
   SET @n_SkuCnt         = 0
   SET @n_CtnByMbol      = 0
   SET @c_SKUBUSR8       = ''
   SET @n_ComponentQty   = 0

   SET @c_Date = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, GETDATE()))), 2) + '/'

   SET @c_Time = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(HOUR, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MINUTE, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(SECOND, GETDATE()))), 2) + ':'

   SET @c_DateTime = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, GETDATE()))), 4)
                   + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(HOUR, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MINUTE, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(SECOND, GETDATE()))), 2)

   -- Retrieve StorerKey and BuyerPO from ORDERS
   SELECT DISTINCT @c_StorerKey = StorerKey, @c_czip = LEFT(C_Zip,5), @c_dischargeplace = DischargePlace
     FROM ORDERS WITH (NOLOCK)
    WHERE ORDERS.OrderKey = @c_OrderKey

   IF ISNULL(RTRIM(@c_CartonNoParm),'') <> '' AND ISNUMERIC(@c_CartonNoParm) = 1
   BEGIN
      SET @n_CartonNoParm = CAST(@c_CartonNoParm AS Int)
   END

/*********************************************/
/* Variables Declaration (End)               */
/*********************************************/

/*********************************************/
/* Define Print Server Path (Start) (LAu001) */
/*********************************************/

   IF ISNULL(RTRIM(@c_MBOLKey),'') = ''
   BEGIN
      SELECT @c_PrinterID = ISNULL(LTRIM(RTRIM(FACILITY.UserDefine19)),'') + ISNULL(LTRIM(@c_PrinterID),'')
           , @c_facility = FACILITY.Facility
        FROM ORDERS ORDERS WITH (NOLOCK)
       INNER JOIN FACILITY FACILITY WITH (NOLOCK) ON ORDERS.FACILITY = FACILITY.FACILITY
       WHERE ORDERS.OrderKey = @c_OrderKey
   END
   ELSE
   BEGIN
      SELECT @c_PrinterID = ISNULL(LTRIM(RTRIM(FACILITY.UserDefine19)),'') + ISNULL(LTRIM(@c_PrinterID),'')
           , @c_facility = FACILITY.Facility
        FROM MBOL MBOL WITH (NOLOCK)
       INNER JOIN FACILITY FACILITY WITH (NOLOCK) ON MBOL.FACILITY = FACILITY.FACILITY
       WHERE MBOL.MBOLKey = @c_MBOLKey
   END
/*********************************************/
/* Define Print Server Path (End) (LAu001)   */
/*********************************************/

   --NJOW03
   EXECUTE nspGetRight @c_facility,  -- facility
         @c_storerkey,      -- Storerkey
         NULL,      -- Sku
         'GetPackWeight', -- Configkey
         @b_success       OUTPUT,
         @c_getpackweight OUTPUT,
         @n_err           OUTPUT,
         @c_errmsg        OUTPUT

/*********************************************/
/* Temp Tables Creation (Start)              */
/*********************************************/
-- (YokeBeen01) - Start
--    IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_XML
--
--   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_Rec'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_Rec
-- (YokeBeen01) - End

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_XML...'
   END

   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') = ''
   BEGIN
      -- Start Ricky for SOS161629
/*      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo Int IDENTITY(1,1),  -- Temp table's PrimaryKey
                 LineText NVARCHAR(1500)    -- XML column
               )
        CREATE INDEX Seq_ind ON #TempGSICartonLabel_XML (SeqNo)  */

      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo Int IDENTITY(1,1) Primary key,  -- Temp table's PrimaryKey
                 LineText NVARCHAR(MAX)                -- XML column   --NJOW07
               )
      -- End Ricky for SOS161629
   END

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_Rec...'
   END

   -- Start tlting02 16/6/09
   IF ISNULL(OBJECT_ID('tempdb..#Pack_Det'),'') = ''
   BEGIN
      Create table #Pack_Det
      (  OrderKey     NVARCHAR(10),
         StorerKey    NVARCHAR(15),
         TTLCnts      Int,
         CartonNo     Int,
         LabelNo      NVARCHAR(20),
         TotQty       Int,
         TotCarton    Int,
         CartonType   NVARCHAR(10),
         UPC          NVARCHAR(20),         --AAY0023 #3
         TotCtnWeight Float NULL,       --NJOW03
         Refno2      NVARCHAR(30) NULL, --NJOW03
         ContentDesc  NVARCHAR(30) NULL, --NJ0W03
         RouteCode    NVARCHAR(20) NULL, --NJOW03
         Address      NVARCHAR(25) NULL, --NJOW03
         City         NVARCHAR(25) NULL, --NJOW03
         State        NVARCHAR(10) NULL, --NJOW03
         Zip          NVARCHAR(10) NULL  --NJOW03
      )
   END

   --(Wan01) - START
   SELECT @c_SortKeyName   = ISNULL(RTRIM(Short),'') 
        , @c_GenSortCodeSP = ISNULL(RTRIM(Long),'') 
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'SORTCODE'
   AND   Code     = @c_dischargeplace
   AND   Storerkey= @c_Storerkey

   IF @c_SortKeyName <> '' 
   BEGIN
      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_GenSortCodeSP AND TYPE = 'P')
      BEGIN
         SET @c_SortCode = ''
         SET @c_SQL = N'EXECUTE ' + @c_GenSortCodeSP           + CHAR(13)   
                    + '  @c_MBOLKey       = @c_MBOLKey '       + CHAR(13)  
                    + ', @c_OrderKey      = @c_OrderKey '      + CHAR(13)  
                    + ', @c_ConsoOrderKey = @c_ConsoOrderKey ' + CHAR(13)  
                    + ', @c_DropID        = @c_DropID '        + CHAR(13)  
                    + ', @n_CartonNoParm  = @n_CartonNoParm '  + CHAR(13)  
                    + ', @c_LabelNoParm   = @c_LabelNoParm '   + CHAR(13)  
                    + ', @c_SortKeyName   = @c_SortKeyName '   + CHAR(13)  
                    + ', @c_SortCode      = @c_SortCode OUTPUT '+ CHAR(13) 
                    + ', @b_Success       = @b_Success  OUTPUT '+ CHAR(13)  
                    + ', @n_Err           = @n_Err      OUTPUT '+ CHAR(13) 
                    + ', @c_ErrMsg        = @c_ErrMsg   OUTPUT '


         SET @c_SQLParm = N'@c_MBOLKey       NVARCHAR(10) '   
                        + ',@c_OrderKey      NVARCHAR(10) '  
                        + ',@c_ConsoOrderKey NVARCHAR(30) '  
                        + ',@c_DropID        NVARCHAR(20) '  
                        + ',@n_CartonNoParm  INT'  
                        + ',@c_LabelNoParm   NVARCHAR(20) '  
                        + ',@c_SortKeyName   NVARCHAR(30) '
                        + ',@c_SortCode      NVARCHAR(30) OUTPUT '
                        + ',@b_Success       INT OUTPUT '
                        + ',@n_Err           INT OUTPUT '
                        + ',@c_ErrMsg        NVARCHAR(250) OUTPUT ' 
        
         EXEC sp_ExecuteSQL @c_SQL  
                           ,@c_SQLParm
                           ,@c_MBOLKey
                           ,@c_OrderKey
                           ,@c_ConsoOrderKey
                           ,@c_DropID
                           ,@n_CartonNoParm
                           ,@c_LabelNoParm
                           ,@c_SortKeyName
                           ,@c_SortCode   OUTPUT
                           ,@b_Success    OUTPUT
                           ,@n_Err        OUTPUT
                           ,@c_ErrMsg     OUTPUT 
        
         IF @@ERROR <> 0 OR @b_Success <> 1  
         BEGIN  
            SET @n_Continue= 3    
         END 
      END
   END
   --(Wan01) - END

   -- Create index sort_ind2 ON #Pack_Det (StorerKey, OrderKey,CartonNo , LabelNo)  -- Ricky for SOS161629
   IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
   BEGIN

      -- (ChewKP05)
      -- Check If MasterPack Template Exist in CodeLkup
      SET @c_MasterPack = '0'

      DECLARE CUR1 CURSOR LOCAL FOR
      SELECT ColValue
      FROM [dbo].[fnc_DelimSplit]('\',@c_TemplateID)
      ORDER BY SeqNo

      OPEN CUR1

      FETCH NEXT FROM CUR1 INTO @c_ColValue
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF EXISTS (SELECT 1 from dbo.CODELKUP WITH (NOLOCK)
                 WHERE ListName = 'TEMPLATEID'
                 AND Code = 'MASTER'
                 AND Long = RTRIM(@c_ColValue) )
         BEGIN
            SET @c_MasterPack = '1'
            BREAK
         END

         FETCH NEXT FROM CUR1 INTO @c_ColValue
      END
      CLOSE CUR1
      DEALLOCATE CUR1

      IF @c_MasterPack = '1'
      BEGIN
         SET @c_PickSlipNo =''
         SET @n_TTLCnts = 0
         SET @n_CartonNo = 0


         SELECT @c_PickSlipNo = PickSlipNo
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey
         GROUP BY PickSlipNo


         -- Get Total of Master Pack
         SELECT @n_TTLCnts = COUNT(DISTINCT PD.RefNo)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo


         -- Get Current Carton No
         SELECT @n_CartonNo = COUNT(DISTINCT PD.RefNo2)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         AND PD.RefNo2 <> ''


         INSERT INTO #Pack_Det ( OrderKey,   StorerKey,     TTLCnts,     CartonNo,
                                 LabelNo,    TotQty,        TotCarton,   CartonType,
                                 UPC,        TotCtnWeight,  Refno2 )  --AAY0023 # 3
         SELECT @c_OrderKey
              , PACKHEADER.StorerKey
              , @n_TTLCnts
            --, @n_CartonNo -- SOS# 256897
              , PACKDETAIL.CartonNo
              , PACKDETAIL.LabelNo
              , SUM(PACKDETAIL.Qty) AS TotQty
              , @n_TTLCnts
              , ISNULL(RTRIM(PACKINFO.CartonType), '')   -- (Vicky01)
              , ISNULL(RTRIM(MAX(PACKDETAIL.UPC)), '')   --AAY0023 #3
              , CASE WHEN PACKINFO.Weight > 0 THEN PACKINFO.Weight ELSE SUM(PACKDETAIL.QTY*SKU.STDGROSSWGT) END --AAYXXX
              , ISNULL(MAX(PACKDETAIL.Refno2),'')
         FROM PACKHEADER PACKHEADER (NOLOCK)             -- (Vicky02) -- (index =Idx_PACKHEADER_orderkey, NOLOCK) -- Ricky for SOS161629
         JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
                                                       AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
         LEFT OUTER JOIN PACKINFO PACKINFO WITH (NOLOCK) ON ( PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo
                                                              AND PACKDETAIL.CartonNo = PACKINFO.CartonNo )
        JOIN SKU (NOLOCK) ON (PACKHEADER.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku)
         WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
         AND   ( PACKDETAIL.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0  )
         AND   ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
                  PACKDETAIL.LabelNo, PACKINFO.CartonType,
                  PACKINFO.WEIGHT --(AAY001)
      END
      ELSE
      BEGIN
         INSERT INTO #Pack_Det ( OrderKey,   StorerKey,     TTLCnts,     CartonNo,
                                 LabelNo,    TotQty,        TotCarton,   CartonType,
                                 UPC,        TotCtnWeight,  Refno2 )  --AAY0023 # 3
         SELECT @c_OrderKey
              , PACKHEADER.StorerKey
              , ISNULL(RTRIM(PACKHEADER.TTLCnts),0)      --AAY0026
              , PACKDETAIL.CartonNo
              , PACKDETAIL.LabelNo
              , SUM(PACKDETAIL.Qty) AS TotQty
              , ISNULL(RTRIM(PACKHEADER.TTLCnts),0)  AS TotCarton      --AAY0026
              , ISNULL(RTRIM(PACKINFO.CartonType), '')   -- (Vicky01)
              , ISNULL(RTRIM(MAX(PACKDETAIL.UPC)), '')   --AAY0023 #3
              , CASE WHEN PACKINFO.Weight > 0 THEN PACKINFO.Weight ELSE SUM(PACKDETAIL.QTY*SKU.STDGROSSWGT) END --AAYXXX
              , ISNULL(MAX(PACKDETAIL.Refno2),'')
         FROM PACKHEADER PACKHEADER (NOLOCK)             -- (Vicky02) -- (index =Idx_PACKHEADER_orderkey, NOLOCK) -- Ricky for SOS161629
         JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
                                                       AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
         LEFT OUTER JOIN PACKINFO PACKINFO WITH (NOLOCK) ON ( PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo
                                                              AND PACKDETAIL.CartonNo = PACKINFO.CartonNo )
         JOIN SKU (NOLOCK) ON (PACKHEADER.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku)
         WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
         AND   ( PACKDETAIL.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0  )
         AND   ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
                  PACKDETAIL.LabelNo, PACKINFO.CartonType,
                  PACKINFO.WEIGHT --(AAY001)
      END
   END --(MC01) - E
   ELSE IF ISNULL(@c_DropID,'') = ''  -- (ChewKP02)
   BEGIN
      INSERT INTO #Pack_Det ( OrderKey,   StorerKey,   TTLCnts,   CartonNo,
                              LabelNo,   TotQty,   TotCarton,   CartonType,
                              UPC, TotCtnWeight, Refno2) --AAY0023 # 3
         SELECT PACKHEADER.OrderKey, PACKHEADER.StorerKey, ISNULL(RTRIM(PACKHEADER.TTLCnts),0), PACKDETAIL.CartonNo,      --AAY0026
             PACKDETAIL.LabelNo,  SUM(PACKDETAIL.Qty) AS TotQty, ISNULL(RTRIM(PACKHEADER.TTLCnts),0) AS TotCarton, ISNULL(RTRIM(PACKINFO.CartonType), ''), -- (Vicky01)      --AAY0026
             ISNULL(RTRIM(MAX(PACKDETAIL.UPC)), ''), --AAY0023 #3
         CASE WHEN PACKINFO.Weight > 0 THEN PACKINFO.Weight ELSE SUM(PACKDETAIL.QTY*SKU.STDGROSSWGT) END, --AAYXXX
         ISNULL(MAX(PACKDETAIL.Refno2),'')
         FROM PACKHEADER PACKHEADER (NOLOCK) -- (Vicky02) -- (index =Idx_PACKHEADER_orderkey, NOLOCK) -- Ricky for SOS161629
              JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
                                                         AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
              LEFT OUTER JOIN PACKINFO PACKINFO WITH (NOLOCK) ON ( PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo
                                                         AND PACKDETAIL.CartonNo = PACKINFO.CartonNo )
              JOIN SKU (NOLOCK) ON (PACKHEADER.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku)
         WHERE PACKHEADER.Orderkey = @c_OrderKey
         AND   ( PACKDETAIL.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0  )
         AND   ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PACKHEADER.OrderKey, PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
                  PACKDETAIL.LabelNo, PACKINFO.CartonType, --PACKHEADER.TotCtnWeight
                  PACKINFO.WEIGHT --(AAY001)

   END
   ELSE -- (ChewKP01)
   BEGIN
      INSERT INTO #Pack_Det ( OrderKey,   StorerKey,   TTLCnts,   CartonNo,
                              LabelNo,   TotQty,   TotCarton,   CartonType,
                              UPC, TotCtnWeight, Refno2) --AAY0023 # 3
         SELECT PACKHEADER.OrderKey, PACKHEADER.StorerKey, ISNULL(PACKHEADER.TTLCnts,0), PACKDETAIL.CartonNo,      --AAY0026
             PACKDETAIL.LabelNo,  SUM(PACKDETAIL.Qty) AS TotQty, ISNULL(PACKHEADER.TTLCnts,0) AS TotCarton, ISNULL(RTRIM(PACKINFO.CartonType), ''), -- (Vicky01)      --AAY0026
             ISNULL(RTRIM(MAX(PACKDETAIL.UPC)), ''),  --AAY0023 #3
             CASE WHEN PACKINFO.Weight > 0 THEN PACKINFO.Weight ELSE SUM(PACKDETAIL.QTY*SKU.STDGROSSWGT) END, --AAYXXX
             ISNULL(MAX(PACKDETAIL.Refno2),'')
         FROM PACKHEADER PACKHEADER (NOLOCK) -- (Vicky02) -- (index =Idx_PACKHEADER_orderkey, NOLOCK) -- Ricky for SOS161629
              JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
                                                         AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
              LEFT OUTER JOIN PACKINFO PACKINFO WITH (NOLOCK) ON ( PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo
                                                         AND PACKDETAIL.CartonNo = PACKINFO.CartonNo )
              JOIN SKU (NOLOCK) ON (PACKHEADER.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku)
         WHERE PACKHEADER.Orderkey = @c_OrderKey
         AND PACKDETAIL.RefNo = ISNULL(@c_DropID,'') -- (ChewKP01)
         AND   ( PACKDETAIL.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0  )
         AND   ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PACKHEADER.OrderKey, PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
                  PACKDETAIL.LabelNo, PACKINFO.CartonType, --PACKHEADER.TotCtnWeight,
                  PACKINFO.WEIGHT --(AAY001)
   END
   -- end tlting02


   IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
   BEGIN
      DECLARE CUR_PACK CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(SKU.Busr7,''), PD.Cartonno
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo
                                         AND PH.StorerKey = PD.StorerKey)
         JOIN SKU (NOLOCK) ON (PH.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
         WHERE PH.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
         AND (PD.RefNo = ISNULL(@c_DropID,'') OR ISNULL(@c_DropID,'') = '')
         AND (PD.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0)
         AND (PD.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PD.Cartonno, ISNULL(SKU.Busr7,'')
         ORDER BY PD.Cartonno, ISNULL(SKU.Busr7,'')
   END   --(MC01) - E
   ELSE
   BEGIN
      --NJOW03
      DECLARE CUR_PACK CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT ISNULL(SKU.Busr7,''), PD.Cartonno
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo
                                         AND PH.StorerKey = PD.StorerKey)
         JOIN SKU (NOLOCK) ON (PH.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
         WHERE PH.Orderkey = @c_OrderKey
         AND (PD.RefNo = ISNULL(@c_DropID,'') OR ISNULL(@c_DropID,'') = '')
         AND (PD.CartonNo = ISNULL(RTRIM(@n_CartonNoParm),0) OR ISNULL(RTRIM(@n_CartonNoParm),0) = 0)
         AND (PD.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         GROUP BY PD.Cartonno, ISNULL(SKU.Busr7,'')
         ORDER BY PD.Cartonno, ISNULL(SKU.Busr7,'')
   END
   OPEN CUR_PACK

   SELECT @n_precartonno = 0, @c_contentdesc = ''

   FETCH NEXT FROM CUR_PACK INTO @c_busr7, @n_curcartonno
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_precartonno <> @n_curcartonno AND @n_precartonno <> 0
      BEGIN
         SELECT @c_contentdesc = LEFT(@c_contentdesc, LEN(@c_contentdesc)-1)
         UPDATE #Pack_Det
         SET ContentDesc = @c_contentdesc
         WHERE Cartonno = @n_precartonno

         SET @c_contentdesc = ''
      END

      SET @n_precartonno = @n_curcartonno
      SET @c_contentdesc = @c_contentdesc + RTRIM(@c_busr7) + ','
      FETCH NEXT FROM CUR_PACK INTO @c_busr7, @n_curcartonno
   END -- While
   CLOSE CUR_PACK
   DEALLOCATE CUR_PACK


   IF @n_precartonno <> 0
   BEGIN
      SELECT @c_contentdesc = LEFT(@c_contentdesc, LEN(@c_contentdesc)-1)
      UPDATE #Pack_Det
      SET ContentDesc = @c_contentdesc
      WHERE Cartonno = @n_precartonno
   END

   SELECT @c_Address = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN address_pobox ELSE address_basic END,
          @c_City = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN city_pobox ELSE city_basic END,
          @c_State = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN state_pobox ELSE state_basic END,
          @c_Zip = CASE WHEN CHARINDEX('POBOX',@c_dischargeplace) > 0 THEN zip_pobox ELSE zip_basic END,
          @c_RouteCode = RouteCode
   FROM USPSAddress (NOLOCK)         WHERE ref_zip = @c_czip

   UPDATE #Pack_Det
   SET address = @c_address,
       city = @c_city,
       state = @c_state,
       zip = @c_zip,
       routecode = @c_routecode

   DECLARE
     @c_Facility_Ship_From_Name NVARCHAR(45),               -- #1   Company
     @c_Facility_Shipping_Address1 NVARCHAR(45),            -- #2   Fac_Descr_1
     @c_Facility_Shipping_Address2 NVARCHAR(45),            -- #3   Fac_Descr_2
     @c_Facility_Shipping_City NVARCHAR(25),                -- #4   Fac_Userdefine01
     @c_Facility_Shipping_State NVARCHAR(2),                -- #5   Fac_Userdefine03
     @c_Facility_Shipping_Zip NVARCHAR(9),                  -- #6   Fac_Userdefine04
     @c_Storer_Name NVARCHAR(25),                           -- #7   S_Company
     @c_Facility_Number NVARCHAR(3),                        -- #8   Facility
     @c_Blank01 NVARCHAR(1),                                -- #9
     @c_Blank02 NVARCHAR(30),                               -- #10
     @c_Carrier_Name NVARCHAR(30),                          -- #11  S_Company
     @c_Proof_Of_Delivery NVARCHAR(17),                     -- #12  Not Mapped
     @c_VICS_BOL NVARCHAR(17),    -- #13  ExternMBOLKey
     @c_Carrier_SCAC_Code NVARCHAR(4),                      -- #14  CarrierKey
     @c_Non_VICS_BOL NVARCHAR(6),                           -- #15  MBOLKey
     @c_Order_Session NVARCHAR(30),                         -- #16  Season Code (not Session)  --AAY025 ROUTING
     @c_Blank03 NVARCHAR(18),                               -- #17
     @c_Blank04 NVARCHAR(30),                               -- #18
     @c_Blank05 NVARCHAR(30),                               -- #19
     @c_Ship_To_Consignee NVARCHAR(15),                     -- #20  Consigneekey
     @c_Ship_To_Consignee_Name NVARCHAR(45),                -- #21  C_Company
     @c_Ship_To_Consignee_Address1 NVARCHAR(45),            -- #22  C_Address1
     @c_Ship_To_Consignee_Address2 NVARCHAR(45),            -- #23  C_Address2
     @c_Ship_To_Consignee_City NVARCHAR(25),                -- #24  C_City
     @c_Ship_To_Consignee_State NVARCHAR(2),                -- #25  C_State
     @c_Ship_To_Consignee_Zip NVARCHAR(18),                 -- #26  C_Zip
     @c_Ship_To_Consignee_ISOCntryCode NVARCHAR(10),        -- #27  C_ISOCntryCode  --AAY0023 #3
     @c_Class_of_Service NVARCHAR(18),                      -- #28  M_Phone2        --AAY0023 #3
     @c_Shipper_Account_No NVARCHAR(18),                    -- #29  M_Fax1          --AAY0023 #3
     @c_Shipment_No NVARCHAR(18),                           -- #30  M_Fax2          --AAY0023 #3
     @c_Final_Destination_Consignee_Name NVARCHAR(45),      -- #31  M_Company
     @c_Final_Destination_Consignee_Address1 NVARCHAR(45),  -- #32  M_Address1
     @c_Final_Destination_Consignee_Address2 NVARCHAR(45),  -- #33  M_Address2
     @c_Final_Destination_Consignee_City NVARCHAR(25),      -- #34  M_City
     @c_Final_Destination_Consignee_State NVARCHAR(2),      -- #35  M_State
     @c_Final_Destination_Consignee_Zip NVARCHAR(18),       -- #36  M_Zip
     @c_Final_Destination_Consignee_Store NVARCHAR(15),     -- #37  MarkForKey/Consigneekey  -- AAY003
     @c_Buying_Store NVARCHAR(15),                          -- #38  B_BillToKey --AAY0019 from 6 to 15 Char
     @c_Blank11 NVARCHAR(1),                                -- #39
     @c_Blank12 NVARCHAR(30) ,                              -- #40
     @c_Ship_To_Consignee_Zip2 NVARCHAR(18),                -- #41  C_Zip
     @c_Buying_Consignee_Zip NVARCHAR(18),      -- #42  Blank
     @c_Storer_Vendor_Num NVARCHAR(10),                     -- #43  UserDeifine05
     @c_Buying_Consignee_Ship_To_Name NVARCHAR(45),         -- #44
     @c_Buying_Consignee_Ship_To_Address1 NVARCHAR(45),     -- #45  B_Address1
     @c_Buying_Consignee_Ship_To_Address2 NVARCHAR(45),     -- #46  B_Address2
     @c_Buying_Consignee_Ship_To_City NVARCHAR(25),         -- #47  B_City
     @c_Buying_Consignee_Ship_To_State NVARCHAR(2),         -- #48  B_State
     @c_Buying_Consignee_Ship_To_Zip NVARCHAR(18),          -- #49  B_Zip
     @c_Buying_Consignee_Region NVARCHAR(10),               -- #50  ISOCntryCode
     @c_Purchase_Order_Number NVARCHAR(24),                 -- #51  ExternOrderKey
     @c_Department_Number NVARCHAR(7),                      -- #52  UserDeifine03
     @c_Department_Name NVARCHAR(30),                       -- #53  UserDeifine10
     @c_PO_Type NVARCHAR(20),                               -- #54  ExternPOKey
     @c_Case_Type NVARCHAR(8),                              -- #55  packinfo_CartonType
     @c_Dock_Number NVARCHAR(6),                            -- #56  Door
     @c_Product_Group NVARCHAR(30),                         -- #57  BUSR5
     @c_PickUp_Date NVARCHAR(17),                           -- #58  MBOL.Userdefine07 --AAY0021
     @c_Order_Product_Group NVARCHAR(5),                    -- #59  ORDERS.LabelPrice --AAY0022
     @c_Carton_Weight NVARCHAR(5),                          -- #60  Carton Weight --AAY0023 #3
     @c_Total_Units_This_Carton NVARCHAR(5),                -- #61  TotQty
     @c_Duplicate_Label_Message NVARCHAR(20),               -- #62  AAY025 LOAD ID Orders.Userdefine01
     @c_Julian_Day NVARCHAR(5),                             -- #63  Julian Day --AAY0023 #5
     @c_Blank17 NVARCHAR(20),                               -- #64
     @c_Blank18 NVARCHAR(25),                               -- #65
     @c_Blank19 NVARCHAR(25),                               -- #66
     @c_Blank20 NVARCHAR(10),                               -- #67
     @c_Blank21 NVARCHAR(10),                               -- #68
     @c_Blank22 NVARCHAR(18),                               -- #69
     @c_Blank23 NVARCHAR(18),                               -- #70
     @c_Sequential_Carton_Number NVARCHAR(5),               -- #71  CartonNo (per store)
     @c_Total_Cartons_Per_Store NVARCHAR(4),                -- #72  TotCarton (per store)
     @c_Order_Start_Date NVARCHAR(8),                       -- #73  OrderDate
     @c_Order_Completion_Date NVARCHAR(8),                  -- #74  DeliveryDate
     @c_Bin_Location NVARCHAR(30),                          -- #75
     @c_CartonTrackingNo NVARCHAR(30),                      -- #76 UPS/FedEx Carton Tracking # --AAY0023 #3
     @c_PrintedBy NVARCHAR(20),                             -- #77
     @c_MasterSKU NVARCHAR(20),                             -- #78  Retailer Master SKU
     @c_SKUDept NVARCHAR(18),                               -- #79  Retailer SKU Dept #        --AAY010
     @c_SKUProd NVARCHAR(18),                               -- #80  Retailer SKU PRoduct Group --AAY010
     @c_Serial_SCC_Without_Check_Digit NVARCHAR(19),        -- #81  with formula
     @c_Serial_SCC_With_Check_Digit NVARCHAR(20),           -- #82  with formula
     @c_Total_Units_This_Carton_2 NVARCHAR(5),              -- #83  TotSkuQty (If single sku in carton)
     @c_GTIN_Code NVARCHAR(14),                             -- #84  Sku (If single sku in carton)
     @c_Style_Description NVARCHAR(30),                     -- #85  SkuDescr (If single sku in carton) --AAY017
     @c_Consignee_Item NVARCHAR(20),                        -- #86  RetailSku (If single sku in carton) --AAY025 16 to 20
     @c_Style_Remark NVARCHAR(50),                          -- #87  Notes1
     @c_Pack_Scale NVARCHAR(18),                            -- #88  PrePack Scale               --AAY0008
--     @c_Pack_Qty NVARCHAR(18),                              -- #89  PrePack Qty Breakdown
     @c_PP_Pack_Qty NVARCHAR(18),                              -- #89  PrePack Qty Breakdown       --AAY20120217
     @c_Pack_Desc NVARCHAR(18),                             -- #90  PrePack Description
     @c_Page_Number NVARCHAR(2),                            -- #91
     @c_Pick_Ticket_Number NVARCHAR(20),                    -- #92  BuyerPO  -- AAY001-#3
     @c_File_Create_Date NVARCHAR(8),                       -- #93  @c_Date
     @c_File_Create_Time NVARCHAR(8),                       -- #94  @c_Time
     @c_Consignee_Account_Number NVARCHAR(8),               -- #95  StorerKey -- AAY004-#1
     @c_Total_Number_Of_Cartons NVARCHAR(10),               -- #96  Apply TotalCarton above
     @c_Sequential_Carton_Number_Ship NVARCHAR(6),          -- #97  CartonNo (per shiptment BY MBOL)
     @c_Pick_Ticket_Suffix NVARCHAR(30),                    -- #98
     @c_Total_Cartons_In_Shipment NVARCHAR(6),              -- #99  TotCartonByMbol (count CartonNo by MBOL)
     @c_PackType NVARCHAR(18),                              -- #100 Pack Type --AAY006
     @c_Reserve01 NVARCHAR(30),                             -- #353
     @c_Reserve02 NVARCHAR(30),                             -- #354
     @c_Reserve03 NVARCHAR(30),                             -- #355
     @c_Reserve04 NVARCHAR(10),                             -- #356 Form Code
     @c_Reserve05 NVARCHAR(10),                             -- #357 Routing Codes
     @c_Reserve06 NVARCHAR(45),                             -- #358 ASTRA Barcode
     @c_Reserve07 NVARCHAR(15),                             -- #359 Tracking Number
     @c_Reserve08 NVARCHAR(30),                             -- #360 Master Form Code
     @c_Reserve09 NVARCHAR(30),                             -- #361 Planned Service Level
     @c_Reserve10 NVARCHAR(45),                             -- #362 Product Name
     @c_Reserve11 NVARCHAR(30),                             -- #363 Special Handling Acronyms
     @c_Reserve12 NVARCHAR(5) ,                             -- #364 Destination Airport Identifier
     @c_Reserve13 NVARCHAR(30),                             -- #365 Ground Barcode
     @c_RCCGroup  NVARCHAR(30),                             -- #366
     @c_MisclFlag NVARCHAR(30),                             -- #367
     @c_Reserve16 NVARCHAR(30),                             -- #368
     @c_Reserve17 NVARCHAR(30),                             -- #369
     @c_Reserve18 NVARCHAR(30)                              -- #370

--      CREATE TABLE #TempGSICartonLabel_Rec
--               ( SeqNo Int IDENTITY(1,1),                                      -- Temp table's PrimaryKey
--                 SeqLineNo as SeqNo,
--                 TotLineItem Int default 0,                                    -- Total Line Items for a carton
--                 OrderKey NVARCHAR(10),                                         -- WMS OrderKey
--                 Facility_Ship_From_Name NVARCHAR(45) default '',               -- #1   Company
--                 Facility_Shipping_Address1 NVARCHAR(45) default '',            -- #2   Fac_Descr_1
--                 Facility_Shipping_Address2 NVARCHAR(45) default '',            -- #3   Fac_Descr_2
--                 Facility_Shipping_City NVARCHAR(25) default '',                -- #4   Fac_Userdefine01
--                 Facility_Shipping_State NVARCHAR(2) default '',                -- #5   Fac_Userdefine03
--                 Facility_Shipping_Zip NVARCHAR(9) default '',                  -- #6   Fac_Userdefine04
--                 Storer_Name NVARCHAR(25) default '',                           -- #7   S_Company
--                 Facility_Number NVARCHAR(3) default '',                        -- #8   Facility
--                 Blank01 NVARCHAR(1) default '',                                -- #9
--                 Blank02 NVARCHAR(30) default '',                               -- #10
--                 Carrier_Name NVARCHAR(30) default '',                          -- #11  S_Company
--                 Proof_Of_Delivery NVARCHAR(17) default '',                     -- #12  Not Mapped
--                 VICS_BOL NVARCHAR(17) default '',                              -- #13  ExternMBOLKey
--                 Carrier_SCAC_Code NVARCHAR(4) default '',                      -- #14  CarrierKey
--                 Non_VICS_BOL NVARCHAR(6) default '',                           -- #15  MBOLKey
--                 Order_Session NVARCHAR(30) default '',                         -- #16  Season Code (not Session)  --AAY025 ROUTING
--                 Blank03 NVARCHAR(18) default '',                               -- #17
--                 Blank04 NVARCHAR(30) default '',                               -- #18
--                 Blank05 NVARCHAR(30) default '',                               -- #19
--                 Ship_To_Consignee NVARCHAR(15) default '',                     -- #20  Consigneekey
--                 Ship_To_Consignee_Name NVARCHAR(45) default '',                -- #21  C_Company
--                 Ship_To_Consignee_Address1 NVARCHAR(45) default '',            -- #22  C_Address1
--                 Ship_To_Consignee_Address2 NVARCHAR(45) default '',            -- #23  C_Address2
--                 Ship_To_Consignee_City NVARCHAR(25) default '',                -- #24  C_City
--                 Ship_To_Consignee_State NVARCHAR(2) default '',                -- #25  C_State
--                 Ship_To_Consignee_Zip NVARCHAR(18) default '',                 -- #26  C_Zip
--                 Ship_To_Consignee_ISOCntryCode NVARCHAR(10) default '',        -- #27  C_ISOCntryCode  --AAY0023 #3
--                 Class_of_Service NVARCHAR(18) default '',                      -- #28  M_Phone2        --AAY0023 #3
--                 Shipper_Account_No NVARCHAR(18) default '',                    -- #29  M_Fax1          --AAY0023 #3
--                 Shipment_No NVARCHAR(18) default '',                           -- #30  M_Fax2          --AAY0023 #3
--                 Final_Destination_Consignee_Name NVARCHAR(45) default '',      -- #31  M_Company
--                 Final_Destination_Consignee_Address1 NVARCHAR(45) default '',  -- #32  M_Address1
--                 Final_Destination_Consignee_Address2 NVARCHAR(45) default '',  -- #33  M_Address2
--                 Final_Destination_Consignee_City NVARCHAR(25) default '',      -- #34  M_City
--                 Final_Destination_Consignee_State NVARCHAR(2) default '',      -- #35  M_State
--                 Final_Destination_Consignee_Zip NVARCHAR(18) default '',       -- #36  M_Zip
--        Final_Destination_Consignee_Store NVARCHAR(15) default '',     -- #37  MarkForKey/Consigneekey  -- AAY003
--                 Buying_Store NVARCHAR(15) default '',                          -- #38  B_BillToKey --AAY0019 from 6 to 15 Char
--                 Blank11 NVARCHAR(1) default '',                                -- #39
--                 Blank12 NVARCHAR(30) default '',                               -- #40
--                 Ship_To_Consignee_Zip2 NVARCHAR(18) default '',                -- #41  C_Zip
--                 Buying_Consignee_Zip NVARCHAR(18) default '',                  -- #42  Blank
--                 Storer_Vendor_Num NVARCHAR(10) default '',                     -- #43  UserDeifine05
--                 Buying_Consignee_Ship_To_Name NVARCHAR(45) default '',         -- #44
--                 Buying_Consignee_Ship_To_Address1 NVARCHAR(45) default '',     -- #45  B_Address1
--                 Buying_Consignee_Ship_To_Address2 NVARCHAR(45) default '',     -- #46  B_Address2
--                 Buying_Consignee_Ship_To_City NVARCHAR(25) default '',         -- #47  B_City
--                 Buying_Consignee_Ship_To_State NVARCHAR(2) default '',         -- #48  B_State
--                 Buying_Consignee_Ship_To_Zip NVARCHAR(18) default '',          -- #49  B_Zip
--                 Buying_Consignee_Region NVARCHAR(10) default '',               -- #50  ISOCntryCode
--                 Purchase_Order_Number NVARCHAR(24) default '',                 -- #51  ExternOrderKey
--                 Department_Number NVARCHAR(7) default '',                      -- #52  UserDeifine03
--                 Department_Name NVARCHAR(30) default '',                       -- #53  UserDeifine10
--                 PO_Type NVARCHAR(20) default '',                               -- #54  ExternPOKey
--                 Case_Type NVARCHAR(8) default '',                              -- #55  packinfo_CartonType
--                 Dock_Number NVARCHAR(6) default '',                            -- #56  Door
--                 Product_Group NVARCHAR(30) default '',                         -- #57  BUSR5
--                 PickUp_Date NVARCHAR(17) default '',                           -- #58  MBOL.Userdefine07 --AAY0021
--                 Order_Product_Group NVARCHAR(5) default '',                    -- #59  ORDERS.LabelPrice --AAY0022
--                 Carton_Weight NVARCHAR(5) default '',                          -- #60  Carton Weight --AAY0023 #3
--                 Total_Units_This_Carton NVARCHAR(5) default '',                -- #61  TotQty
--                 Duplicate_Label_Message NVARCHAR(20) default '',               -- #62  AAY025 LOAD ID Orders.Userdefine01
--                 Julian_Day NVARCHAR(5) default '',                             -- #63  Julian Day --AAY0023 #5
--                 Blank17 NVARCHAR(20) default '',                               -- #64
--                 Blank18 NVARCHAR(25) default '',                               -- #65
--                 Blank19 NVARCHAR(25) default '',                               -- #66
--                 Blank20 NVARCHAR(10) default '',                               -- #67
--                 Blank21 NVARCHAR(10) default '',                               -- #68
--                 Blank22 NVARCHAR(18) default '',                               -- #69
--                 Blank23 NVARCHAR(18) default '',                               -- #70
--                 Sequential_Carton_Number NVARCHAR(5) default '',               -- #71  CartonNo (per store)
--                 Total_Cartons_Per_Store NVARCHAR(4) default '',                -- #72  TotCarton (per store)
--                 Order_Start_Date NVARCHAR(8) default '',                       -- #73  OrderDate
--                 Order_Completion_Date NVARCHAR(8) default '',                  -- #74  DeliveryDate
--                 Bin_Location NVARCHAR(30) default '',                          -- #75
--                 CartonTrackingNo NVARCHAR(30) default '',                      -- #76 UPS/FedEx Carton Tracking # --AAY0023 #3
--                 PrintedBy NVARCHAR(20) default '',                             -- #77
--                 MasterSKU NVARCHAR(20) default '',                             -- #78  Retailer Master SKU
--                 SKUDept NVARCHAR(18) default '',                               -- #79  Retailer SKU Dept #        --AAY010
--                 SKUProd NVARCHAR(18) default '',                               -- #80  Retailer SKU PRoduct Group --AAY010
--                 Serial_SCC_Without_Check_Digit NVARCHAR(19) default '',        -- #81  with formula
--                 Serial_SCC_With_Check_Digit NVARCHAR(20) default '',           -- #82  with formula
--                 Total_Units_This_Carton_2 NVARCHAR(5) default '',              -- #83  TotSkuQty (If single sku in carton)
--                 GTIN_Code NVARCHAR(14) default '',                             -- #84  Sku (If single sku in carton)
--                 Style_Description NVARCHAR(30) default '',                     -- #85  SkuDescr (If single sku in carton) --AAY017
--                 Consignee_Item NVARCHAR(20) default '',                        -- #86  RetailSku (If single sku in carton) --AAY025 16 to 20
--                 Style_Remark NVARCHAR(50) default '',                          -- #87  Notes1
--                 Pack_Scale NVARCHAR(18) default '',                            -- #88  PrePack Scale               --AAY0008
--                 Pack_Qty NVARCHAR(18) default '',                              -- #89  PrePack Qty Breakdown
--                 Pack_Desc NVARCHAR(18) default '',                             -- #90  PrePack Description
--                 Page_Number NVARCHAR(2) default '1',                           -- #91
--                 Pick_Ticket_Number NVARCHAR(20) default '',                    -- #92  BuyerPO  -- AAY001-#3
--                 File_Create_Date NVARCHAR(8) default '',                       -- #93  @c_Date
--                 File_Create_Time NVARCHAR(8) default '',                       -- #94  @c_Time
--                 Consignee_Account_Number NVARCHAR(8) default '',               -- #95  StorerKey -- AAY004-#1
--                 Total_Number_Of_Cartons NVARCHAR(10) default '',               -- #96  Apply TotalCarton above
--                 Sequential_Carton_Number_Ship NVARCHAR(6) default '',          -- #97  CartonNo (per shiptment BY MBOL)
--                 Pick_Ticket_Suffix NVARCHAR(30) default '',                    -- #98
--                 Total_Cartons_In_Shipment NVARCHAR(6) default '',              -- #99  TotCartonByMbol (count CartonNo by MBOL)
--                 PackType NVARCHAR(18) default '',                              -- #100 Pack Type --AAY006
--                 Line_Item_01_Style NVARCHAR(20) default '',                    -- #101 Style --AAY0017
--                 Line_Item_01_Color NVARCHAR(10) default '',                    -- #102 Color --AAY0017
--                 Line_Item_01_Measurement NVARCHAR(5) default '',               -- #103 Measurement
--                 Line_Item_01_Size_Description NVARCHAR(5) default '',          -- #104 Size_Description
--                 Line_Item_01_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #105 Pack_Qty
--                 Line_Item_01_ItemNum NVARCHAR(36) default '',                  -- #106 Sku
--                 Line_Item_01_RetailSKU NVARCHAR(20) default '',                -- #107 Retail SKU
--                 Line_Item_02_Style NVARCHAR(20) default '',                    -- #108 Style --AAY0017
--                 Line_Item_02_Color NVARCHAR(10) default '',                    -- #109 Color --AAY0017
--                 Line_Item_02_Measurement NVARCHAR(5) default '',               -- #110 Measurement
--                 Line_Item_02_Size_Description NVARCHAR(5) default '',          -- #111 Size
--                 Line_Item_02_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #112 PACKDETAIL.Qty
--                 Line_Item_02_ItemNum NVARCHAR(36) default '',                  -- #113 Sku
--                 Line_Item_02_RetailSKU NVARCHAR(20) default '',                -- #114 Retail SKU
--                 Line_Item_03_Style NVARCHAR(20) default '',                    -- #115 Style --AAY0017
--                 Line_Item_03_Color NVARCHAR(10) default '',                    -- #116 Color --AAY0017
--                 Line_Item_03_Measurement NVARCHAR(5) default '',               -- #117 Measurement
--                 Line_Item_03_Size_Description NVARCHAR(5) default '',          -- #118 Size
--                 Line_Item_03_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #119 PACKDETAIL.Qty
--                 Line_Item_03_ItemNum NVARCHAR(36) default '',                  -- #120 Sku
--                 Line_Item_03_RetailSKU NVARCHAR(20) default '',                -- #121 Retail SKU
--                 Line_Item_04_Style NVARCHAR(20) default '',                    -- #122 Style --AAY0017
--                 Line_Item_04_Color NVARCHAR(10) default '',                    -- #123 Color --AAY0017
--                 Line_Item_04_Measurement NVARCHAR(5) default '',               -- #124 Measurement
--                 Line_Item_04_Size_Description NVARCHAR(5) default '',          -- #125 Size
--                 Line_Item_04_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #126 PACKDETAIL.Qty
--                 Line_Item_04_ItemNum NVARCHAR(36) default '',                  -- #127 Sku
--                 Line_Item_04_RetailSKU NVARCHAR(20) default '',                -- #128 Retail SKU
--                 Line_Item_05_Style NVARCHAR(20) default '',                    -- #129 Style --AAY0017
--                 Line_Item_05_Color NVARCHAR(10) default '',                    -- #130 Color --AAY0017
--                 Line_Item_05_Measurement NVARCHAR(5) default '',               -- #131 Measurement
--                 Line_Item_05_Size_Description NVARCHAR(5) default '',          -- #132 Size
--                 Line_Item_05_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #133 PACKDETAIL.Qty
--                 Line_Item_05_ItemNum NVARCHAR(36) default '',                  -- #134 Sku
--                 Line_Item_05_RetailSKU NVARCHAR(20) default '',                -- #135 Retail SKU
--                 Line_Item_06_Style NVARCHAR(20) default '',                    -- #136 Style --AAY0017
--                 Line_Item_06_Color NVARCHAR(10) default '',                    -- #137 Color --AAY0017
--                 Line_Item_06_Measurement NVARCHAR(5) default '',               -- #138 Measurement
--                 Line_Item_06_Size_Description NVARCHAR(5) default '',          -- #139 Size
--                 Line_Item_06_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #140 PACKDETAIL.Qty
--                 Line_Item_06_ItemNum NVARCHAR(36) default '',                  -- #141 Sku
--                 Line_Item_06_RetailSKU NVARCHAR(20) default '',                -- #142 Retail SKU
--                 Line_Item_07_Style NVARCHAR(20) default '',                    -- #143 Style --AAY0017
--                 Line_Item_07_Color NVARCHAR(10) default '',                    -- #144 Color --AAY0017
--                 Line_Item_07_Measurement NVARCHAR(5) default '',               -- #145 Measurement
--                 Line_Item_07_Size_Description NVARCHAR(5) default '',          -- #146 Size
--                 Line_Item_07_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #147 PACKDETAIL.Qty
--                 Line_Item_07_ItemNum NVARCHAR(36) default '',                  -- #148 Sku
--                 Line_Item_07_RetailSKU NVARCHAR(20) default '',                -- #149 Retail SKU
--                 Line_Item_08_Style NVARCHAR(20) default '',                    -- #150 Style --AAY0017
--                 Line_Item_08_Color NVARCHAR(10) default '',                    -- #151 Color --AAY0017
--                 Line_Item_08_Measurement NVARCHAR(5) default '',               -- #152 Measurement
--                 Line_Item_08_Size_Description NVARCHAR(5) default '',          -- #153 Size
--                 Line_Item_08_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #154 PACKDETAIL.Qty
--                 Line_Item_08_ItemNum NVARCHAR(36) default '',                  -- #155 Sku
--                 Line_Item_08_RetailSKU NVARCHAR(20) default '',                -- #156 Retail SKU
--                 Line_Item_09_Style NVARCHAR(20) default '',                    -- #157 Style --AAY0017
--                 Line_Item_09_Color NVARCHAR(10) default '',                    -- #158 Color --AAY0017
--                 Line_Item_09_Measurement NVARCHAR(5) default '',               -- #159 Measurement
--                 Line_Item_09_Size_Description NVARCHAR(5) default '',          -- #160 Size
--                 Line_Item_09_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #161 PACKDETAIL.Qty
--                 Line_Item_09_ItemNum NVARCHAR(36) default '',                  -- #162 Sku
--                 Line_Item_09_RetailSKU NVARCHAR(20) default '',                -- #163 Retail SKU
--                 Line_Item_10_Style NVARCHAR(20) default '',                    -- #164 Style --AAY0017
--                 Line_Item_10_Color NVARCHAR(10) default '',                    -- #165 Color --AAY0017
--                 Line_Item_10_Measurement NVARCHAR(5) default '',               -- #166 Measurement
--                 Line_Item_10_Size_Description NVARCHAR(5) default '',          -- #167 Size
--                 Line_Item_10_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #168 PACKDETAIL.Qty
--                 Line_Item_10_ItemNum NVARCHAR(36) default '',                  -- #169 Sku
--                 Line_Item_10_RetailSKU NVARCHAR(20) default '',                -- #170 Retail SKU
--                 Line_Item_11_Style NVARCHAR(20) default '',                    -- #171 Style --AAY0017
--                 Line_Item_11_Color NVARCHAR(10) default '',                    -- #172 Color --AAY0017
--                 Line_Item_11_Measurement NVARCHAR(5) default '',               -- #173 Measurement
--                 Line_Item_11_Size_Description NVARCHAR(5) default '',          -- #174 Size
--                 Line_Item_11_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #175 PACKDETAIL.Qty
--                 Line_Item_11_ItemNum NVARCHAR(36) default '',                  -- #176 Sku
--                 Line_Item_11_RetailSKU NVARCHAR(20) default '',                -- #177 Retail SKU
--                 Line_Item_12_Style NVARCHAR(20) default '',                    -- #178 Style --AAY0017
--                 Line_Item_12_Color NVARCHAR(10) default '',                    -- #179 Color --AAY0017
--                 Line_Item_12_Measurement NVARCHAR(5) default '',               -- #180 Measurement
--                 Line_Item_12_Size_Description NVARCHAR(5) default '',          -- #181 Size
--                 Line_Item_12_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #182 PACKDETAIL.Qty
--                 Line_Item_12_ItemNum NVARCHAR(36) default '',                  -- #183 Sku
--                 Line_Item_12_RetailSKU NVARCHAR(20) default '',                -- #184 Retail SKU
--                 Line_Item_13_Style NVARCHAR(20) default '',                    -- #185 Style --AAY0017
--                 Line_Item_13_Color NVARCHAR(10) default '',                    -- #186 Color --AAY0017
--                 Line_Item_13_Measurement NVARCHAR(5) default '',               -- #187 Measurement
--                 Line_Item_13_Size_Description NVARCHAR(5) default '',          -- #188 Size
--                 Line_Item_13_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #189 PACKDETAIL.Qty
--                 Line_Item_13_ItemNum NVARCHAR(36) default '',                  -- #190 Sku
--                 Line_Item_13_RetailSKU NVARCHAR(20) default '',                -- #191 Retail SKU
--                 Line_Item_14_Style NVARCHAR(20) default '',                    -- #192 Style --AAY0017
--                 Line_Item_14_Color NVARCHAR(10) default '',                    -- #193 Color --AAY0017
--                 Line_Item_14_Measurement NVARCHAR(5) default '',               -- #194 Measurement
--                 Line_Item_14_Size_Description NVARCHAR(5) default '',          -- #195 Size
--                 Line_Item_14_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #196 PACKDETAIL.Qty
--                 Line_Item_14_ItemNum NVARCHAR(36) default '',                  -- #197 Sku
--                 Line_Item_14_RetailSKU NVARCHAR(20) default '',                -- #198 Retail SKU
--                 Line_Item_15_Style NVARCHAR(20) default '',                    -- #199 Style --AAY0017
--                 Line_Item_15_Color NVARCHAR(10) default '',                    -- #200 Color --AAY0017
--                 Line_Item_15_Measurement NVARCHAR(5) default '',               -- #201 Measurement
--                 Line_Item_15_Size_Description NVARCHAR(5) default '',          -- #202 Size
--                 Line_Item_15_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #203 PACKDETAIL.Qty
--                 Line_Item_15_ItemNum NVARCHAR(36) default '',                  -- #204 Sku
--                 Line_Item_15_RetailSKU NVARCHAR(20) default '',                -- #205 Retail SKU
--                 Line_Item_16_Style NVARCHAR(20) default '',                    -- #206 Style --AAY0017
--                 Line_Item_16_Color NVARCHAR(10) default '',                    -- #207 Color --AAY0017
--                 Line_Item_16_Measurement NVARCHAR(5) default '',               -- #208 Measurement
--                 Line_Item_16_Size_Description NVARCHAR(5) default '',          -- #209 Size
--                 Line_Item_16_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #210 PACKDETAIL.Qty
--                 Line_Item_16_ItemNum NVARCHAR(36) default '',                  -- #211 Sku
--                 Line_Item_16_RetailSKU NVARCHAR(20) default '',                -- #212 Retail SKU
--                 Line_Item_17_Style NVARCHAR(20) default '',                    -- #213 Style --AAY0017
--                 Line_Item_17_Color NVARCHAR(10) default '',                    -- #214 Color --AAY0017
--                 Line_Item_17_Measurement NVARCHAR(5) default '',               -- #215 Measurement
--                 Line_Item_17_Size_Description NVARCHAR(5) default '',          -- #216 Size
--                 Line_Item_17_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #217 PACKDETAIL.Qty
--                 Line_Item_17_ItemNum NVARCHAR(36) default '',                  -- #218 Sku
--                 Line_Item_17_RetailSKU NVARCHAR(20) default '',                -- #219 Retail SKU
--                 Line_Item_18_Style NVARCHAR(20) default '',                    -- #220 Style --AAY0017
--                 Line_Item_18_Color NVARCHAR(10) default '',                    -- #221 Color --AAY0017
--                 Line_Item_18_Measurement NVARCHAR(5) default '',               -- #222 Measurement
--                 Line_Item_18_Size_Description NVARCHAR(5) default '',          -- #223 Size
--                 Line_Item_18_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #224 PACKDETAIL.Qty
--                 Line_Item_18_ItemNum NVARCHAR(36) default '',                  -- #225 Sku
--                 Line_Item_18_RetailSKU NVARCHAR(20) default '',                -- #226 Retail SKU
--                 Line_Item_19_Style NVARCHAR(20) default '',                    -- #227 Style --AAY0017
--                 Line_Item_19_Color NVARCHAR(10) default '',                    -- #228 Color --AAY0017
--                 Line_Item_19_Measurement NVARCHAR(5) default '',               -- #229 Measurement
--                 Line_Item_19_Size_Description NVARCHAR(5) default '',          -- #230 Size
--                 Line_Item_19_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #231 PACKDETAIL.Qty
--                 Line_Item_19_ItemNum NVARCHAR(36) default '',                  -- #232 Sku
--                 Line_Item_19_RetailSKU NVARCHAR(20) default '',                -- #233 Retail SKU
--                 Line_Item_20_Style NVARCHAR(20) default '',                    -- #234 Style --AAY0017
--                 Line_Item_20_Color NVARCHAR(10) default '',                    -- #235 Color --AAY0017
--                 Line_Item_20_Measurement NVARCHAR(5) default '',               -- #236 Measurement
--                 Line_Item_20_Size_Description NVARCHAR(5) default '',          -- #237 Size
--                 Line_Item_20_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #238 PACKDETAIL.Qty
--                 Line_Item_20_ItemNum NVARCHAR(36) default '',                  -- #239 Sku
--                 Line_Item_20_RetailSKU NVARCHAR(20) default '',                -- #240 Retail SKU
--                 Line_Item_21_Style NVARCHAR(20) default '',                    -- #241 Style --AAY0017
--                 Line_Item_21_Color NVARCHAR(10) default '',                    -- #242 Color --AAY0017
--                 Line_Item_21_Measurement NVARCHAR(5) default '',               -- #243 Measurement
--                 Line_Item_21_Size_Description NVARCHAR(5) default '',          -- #244 Size
--                 Line_Item_21_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #245 PACKDETAIL.Qty
-- Line_Item_21_ItemNum NVARCHAR(36) default '',                  -- #246 Sku
--                 Line_Item_21_RetailSKU NVARCHAR(20) default '',                -- #247 Retail SKU
--                 Line_Item_22_Style NVARCHAR(20) default '',                    -- #248 Style --AAY0017
--                 Line_Item_22_Color NVARCHAR(10) default '',                    -- #249 Color --AAY0017
--                 Line_Item_22_Measurement NVARCHAR(5) default '',               -- #250 Measurement
--                 Line_Item_22_Size_Description NVARCHAR(5) default '',          -- #251 Size
--                 Line_Item_22_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #252 PACKDETAIL.Qty
--                 Line_Item_22_ItemNum NVARCHAR(36) default '',                  -- #253 Sku
--                 Line_Item_22_RetailSKU NVARCHAR(20) default '',                -- #254 Retail SKU
--                 Line_Item_23_Style NVARCHAR(20) default '',                    -- #255 Style --AAY0017
--                 Line_Item_23_Color NVARCHAR(10) default '',                    -- #256 Color --AAY0017
--                 Line_Item_23_Measurement NVARCHAR(5) default '',               -- #257 Measurement
--                 Line_Item_23_Size_Description NVARCHAR(5) default '',          -- #258 Size
--                 Line_Item_23_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #259 PACKDETAIL.Qty
--                 Line_Item_23_ItemNum NVARCHAR(36) default '',                  -- #260 Sku
--                 Line_Item_23_RetailSKU NVARCHAR(20) default '',                -- #261 Retail SKU
--                 Line_Item_24_Style NVARCHAR(20) default '',                    -- #262 Style --AAY0017
--                 Line_Item_24_Color NVARCHAR(10) default '',                    -- #263 Color --AAY0017
--                 Line_Item_24_Measurement NVARCHAR(5) default '',               -- #264 Measurement
--                 Line_Item_24_Size_Description NVARCHAR(5) default '',          -- #265 Size
--                 Line_Item_24_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #266 PACKDETAIL.Qty
--                 Line_Item_24_ItemNum NVARCHAR(36) default '',                  -- #267 Sku
--                 Line_Item_24_RetailSKU NVARCHAR(20) default '',                -- #268 Retail SKU
--                 Line_Item_25_Style NVARCHAR(20) default '',                    -- #269 Style --AAY0017
--                 Line_Item_25_Color NVARCHAR(10) default '',                    -- #270 Color --AAY0017
--                 Line_Item_25_Measurement NVARCHAR(5) default '',               -- #271 Measurement
--                 Line_Item_25_Size_Description NVARCHAR(5) default '',          -- #272 Size
--                 Line_Item_25_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #273 Pack_Qty
--                 Line_Item_25_ItemNum NVARCHAR(36) default '',                  -- #274 Sku
--                 Line_Item_25_RetailSKU NVARCHAR(20) default '',                -- #275 Retail SKU
--                 Line_Item_26_Style NVARCHAR(20) default '',                    -- #276 Style --AAY0017
--                 Line_Item_26_Color NVARCHAR(10) default '',                    -- #277 Color --AAY0017
--                 Line_Item_26_Measurement NVARCHAR(5) default '',               -- #278 Measurement
--                 Line_Item_26_Size_Description NVARCHAR(5) default '',          -- #279 Size
--                 Line_Item_26_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #280 Pack_Qty
--                 Line_Item_26_ItemNum NVARCHAR(36) default '',                -- #281 Sku
--                 Line_Item_26_RetailSKU NVARCHAR(20) default '',                -- #282 Retail SKU
--                 Line_Item_27_Style NVARCHAR(20) default '',                    -- #283 Style --AAY0017
--                 Line_Item_27_Color NVARCHAR(10) default '',                    -- #284 Color --AAY0017
--                 Line_Item_27_Measurement NVARCHAR(5) default '',               -- #285 Measurement
--                 Line_Item_27_Size_Description NVARCHAR(5) default '',          -- #286 Size
--                 Line_Item_27_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #287 Pack_Qty
--                 Line_Item_27_ItemNum NVARCHAR(36) default '',                  -- #288 Sku
--                 Line_Item_27_RetailSKU NVARCHAR(20) default '',                -- #289 Retail SKU
--                 Line_Item_28_Style NVARCHAR(20) default '',                    -- #290 Style --AAY0017
--                 Line_Item_28_Color NVARCHAR(10) default '',                    -- #291 Color --AAY0017
--                 Line_Item_28_Measurement NVARCHAR(5) default '',               -- #292 Measurement
--                 Line_Item_28_Size_Description NVARCHAR(5) default '',          -- #293 Size
--                 Line_Item_28_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #294 PACKDETAIL.Qty
--                 Line_Item_28_ItemNum NVARCHAR(36) default '',                  -- #295 Sku
--                 Line_Item_28_RetailSKU NVARCHAR(20) default '',                -- #296 Retail SKU
--                 Line_Item_29_Style NVARCHAR(20) default '',                    -- #297 Style --AAY0017
--                 Line_Item_29_Color NVARCHAR(10) default '',                    -- #298 Color --AAY0017
--                 Line_Item_29_Measurement NVARCHAR(5) default '',               -- #299 Measurement
--                 Line_Item_29_Size_Description NVARCHAR(5) default '',          -- #300 Size
--                 Line_Item_29_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #301 PACKDETAIL.Qty
--                 Line_Item_29_ItemNum NVARCHAR(36) default '',                  -- #302 Sku
--                 Line_Item_29_RetailSKU NVARCHAR(20) default '',                -- #303 Retail SKU
--                 Line_Item_30_Style NVARCHAR(20) default '',                    -- #304 Style --AAY0017
--                 Line_Item_30_Color NVARCHAR(10) default '',                    -- #305 Color --AAY0017
--                 Line_Item_30_Measurement NVARCHAR(5) default '',               -- #306 Measurement
--                 Line_Item_30_Size_Description NVARCHAR(5) default '',          -- #307 Size
--                 Line_Item_30_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #308 PACKDETAIL.Qty
--                 Line_Item_30_ItemNum NVARCHAR(36) default '',                  -- #309 Sku
--                 Line_Item_30_RetailSKU NVARCHAR(20) default '',                -- #310 Retail SKU
--                 Line_Item_31_Style NVARCHAR(20) default '',                    -- #311 Style --A311017
--                 Line_Item_31_Color NVARCHAR(10) default '',                    -- #312 Color --AAY0017
--                 Line_Item_31_Measurement NVARCHAR(5) default '',               -- #313 Measurement
--                 Line_Item_31_Size_Description NVARCHAR(5) default '',          -- #314 Size
--                 Line_Item_31_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #315 PACKDETAIL.Qty
--                 Line_Item_31_ItemNum NVARCHAR(36) default '',                  -- #316 Sku
--                 Line_Item_31_RetailSKU NVARCHAR(20) default '',                -- #317 Retail SKU
--                 Line_Item_32_Style NVARCHAR(20) default '',                    -- #318 Style --AAY0017
--                 Line_Item_32_Color NVARCHAR(10) default '',                    -- #319 Color --AAY0017
--                 Line_Item_32_Measurement NVARCHAR(5) default '',               -- #320 Measurement
--                 Line_Item_32_Size_Description NVARCHAR(5) default '',          -- #321 Size
--                 Line_Item_32_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #322 PACKDETAIL.Qty
--                 Line_Item_32_ItemNum NVARCHAR(36) default '',                  -- #323 Sku
--                 Line_Item_32_RetailSKU NVARCHAR(20) default '',                -- #324 Retail SKU
--                 Line_Item_33_Style NVARCHAR(20) default '',                    -- #325 Style --AAY0017
--                 Line_Item_33_Color NVARCHAR(10) default '',                    -- #326 Color --AAY0017
--                 Line_Item_33_Measurement NVARCHAR(5) default '',               -- #327 Measurement
--                 Line_Item_33_Size_Description NVARCHAR(5) default '',          -- #328 Size
--                 Line_Item_33_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #329 PACKDETAIL.Qty
--                 Line_Item_33_ItemNum NVARCHAR(36) default '',                  -- #330 Sku
--                 Line_Item_33_RetailSKU NVARCHAR(20) default '',                -- #331 Retail SKU
--                 Line_Item_34_Style NVARCHAR(20) default '',                    -- #332 Style --AAY0017
--                 Line_Item_34_Color NVARCHAR(10) default '',                    -- #333 Color --AAY0017
--                 Line_Item_34_Measurement NVARCHAR(5) default '',               -- #334 Measurement
--                 Line_Item_34_Size_Description NVARCHAR(5) default '',          -- #335 Size
--                 Line_Item_34_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #336 PACKDETAIL.Qty
--                 Line_Item_34_ItemNum NVARCHAR(36) default '',                  -- #337 Sku
--                 Line_Item_34_RetailSKU NVARCHAR(20) default '',                -- #338 Retail SKU
--                 Line_Item_35_Style NVARCHAR(20) default '',                    -- #339 Style --AAY0017
--                 Line_Item_35_Color NVARCHAR(10) default '',                    -- #340 Color --AAY0017
--                 Line_Item_35_Measurement NVARCHAR(5) default '',               -- #341 Measurement
--                 Line_Item_35_Size_Description NVARCHAR(5) default '',          -- #342 Size
--                 Line_Item_35_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #343 PACKDETAIL.Qty
--                 Line_Item_35_ItemNum NVARCHAR(36) default '',                  -- #344 Sku
--                 Line_Item_35_RetailSKU NVARCHAR(20) default '',                -- #345 Retail SKU
--                 Line_Item_36_Style NVARCHAR(20) default '',                    -- #346 Style --AAY0017
--                 Line_Item_36_Color NVARCHAR(10) default '',                    -- #347 Color --AAY0017
--                 Line_Item_36_Measurement NVARCHAR(5) default '',               -- #348 Measurement
--                 Line_Item_36_Size_Description NVARCHAR(5) default '',          -- #349 Size
--                 Line_Item_36_NoOfUnits_For_Size NVARCHAR(5) default '',        -- #350 PACKDETAIL.Qty
--                 Line_Item_36_ItemNum NVARCHAR(36) default '',                  -- #351 Sku
--                 Line_Item_36_RetailSKU NVARCHAR(20) default '',                -- #352 Retail SKU
--                 --NJOW05 Extended
--                 Reserve01 NVARCHAR(30) default '',                             -- #353
--                 Reserve02 NVARCHAR(30) default '',                             -- #354
--                 Reserve03 NVARCHAR(30) default '',                             -- #355
--                 --NJOW09 Start
--                 Reserve04 NVARCHAR(10) default '',                             -- #356 Form Code
--                 Reserve05 NVARCHAR(10) default '',                             -- #357 Routing Codes
--                 Reserve06 NVARCHAR(45) default '',                             -- #358 ASTRA Barcode
--                 Reserve07 NVARCHAR(15) default '',                             -- #359 Tracking Number
--                 Reserve08 NVARCHAR(30) default '',                             -- #360 Master Form Code
--                 Reserve09 NVARCHAR(30) default '',                             -- #361 Planned Service Level
--                 Reserve10 NVARCHAR(45) default '',                             -- #362 Product Name
--                 Reserve11 NVARCHAR(30) default '',                             -- #363 Special Handling Acronyms
--                 Reserve12 NVARCHAR(5)  default '',                             -- #364 Destination Airport Identifier
--                 Reserve13 NVARCHAR(30) default '',                             -- #365 Ground Barcode
--                 --NJOW09 End
--                 Reserve14 NVARCHAR(30) default '',                             -- #366
--                 Reserve15 NVARCHAR(30) default '',                             -- #367
--                 Reserve16 NVARCHAR(30) default '',                             -- #368
--                 Reserve17 NVARCHAR(30) default '',                             -- #369
--                 Reserve18 NVARCHAR(30) default '',                             -- #370
--                 Line_Item2_01_Style NVARCHAR(20) default '',                   -- #371Style
--                 Line_Item2_01_Color NVARCHAR(10) default '',                   -- #372Color
--                 Line_Item2_01_Measurement NVARCHAR(5) default '',              -- #373Measurement
--                 Line_Item2_01_Size_Description NVARCHAR(5) default '',         -- #374Size
--                 Line_Item2_01_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #375PACKDETAIL.Qty
--                 Line_Item2_01_ItemNum NVARCHAR(36) default '',                 -- #376Sku
--                 Line_Item2_01_RetailSKU NVARCHAR(20) default '',               -- #377Retail SKU
--                 Line_Item2_01_RetailCompSKU NVARCHAR(30) default '',           -- #378Retail Component SKU
--                 Line_Item2_01_Reserve01 NVARCHAR(30) default '',               -- #379ParentSKU
--                 Line_Item2_01_Reserve02 NVARCHAR(30) default '',               -- #380
--                 Line_Item2_01_Reserve03 NVARCHAR(30) default '',               -- #381
--                 Line_Item2_01_Reserve04 NVARCHAR(30) default '',               -- #382
--                 Line_Item2_01_Reserve05 NVARCHAR(30) default '',               -- #383
--                 Line_Item2_02_Style NVARCHAR(20) default '',                   -- #384Style
--                 Line_Item2_02_Color NVARCHAR(10) default '',                   -- #385Color
--                 Line_Item2_02_Measurement NVARCHAR(5) default '',              -- #386Measurement
--         Line_Item2_02_Size_Description NVARCHAR(5) default '',         -- #387Size
--                 Line_Item2_02_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #388PACKDETAIL.Qty
--                 Line_Item2_02_ItemNum NVARCHAR(36) default '',                 -- #389Sku
--                 Line_Item2_02_RetailSKU NVARCHAR(20) default '',               -- #390Retail SKU
--                 Line_Item2_02_RetailCompSKU NVARCHAR(30) default '',           -- #391Retail Component SKU
--                 Line_Item2_02_Reserve01 NVARCHAR(30) default '',               -- #392ParentSKU
--                 Line_Item2_02_Reserve02 NVARCHAR(30) default '',               -- #393
--                 Line_Item2_02_Reserve03 NVARCHAR(30) default '',               -- #394
--                 Line_Item2_02_Reserve04 NVARCHAR(30) default '',               -- #395
--                 Line_Item2_02_Reserve05 NVARCHAR(30) default '',               -- #396
--                 Line_Item2_03_Style NVARCHAR(20) default '',                   -- #397Style
--                 Line_Item2_03_Color NVARCHAR(10) default '',                   -- #398Color
--                 Line_Item2_03_Measurement NVARCHAR(5) default '',              -- #399Measurement
--                 Line_Item2_03_Size_Description NVARCHAR(5) default '',         -- #400Size
--                 Line_Item2_03_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #401PACKDETAIL.Qty
--                 Line_Item2_03_ItemNum NVARCHAR(36) default '',                 -- #402Sku
--                 Line_Item2_03_RetailSKU NVARCHAR(20) default '',               -- #403Retail SKU
--                 Line_Item2_03_RetailCompSKU NVARCHAR(30) default '',           -- #404Retail Component SKU
--                 Line_Item2_03_Reserve01 NVARCHAR(30) default '',               -- #405ParentSKU
--                 Line_Item2_03_Reserve02 NVARCHAR(30) default '',               -- #406
--                 Line_Item2_03_Reserve03 NVARCHAR(30) default '',               -- #407
--                 Line_Item2_03_Reserve04 NVARCHAR(30) default '',               -- #408
--                 Line_Item2_03_Reserve05 NVARCHAR(30) default '',               -- #409
--                 Line_Item2_04_Style NVARCHAR(20) default '',                   -- #410Style
--                 Line_Item2_04_Color NVARCHAR(10) default '',                   -- #411Color
--                 Line_Item2_04_Measurement NVARCHAR(5) default '',              -- #412Measurement
--                 Line_Item2_04_Size_Description NVARCHAR(5) default '',         -- #413Size
--                 Line_Item2_04_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #414PACKDETAIL.Qty
--                 Line_Item2_04_ItemNum NVARCHAR(36) default '',                 -- #415Sku
--                 Line_Item2_04_RetailSKU NVARCHAR(20) default '',               -- #416Retail SKU
--                 Line_Item2_04_RetailCompSKU NVARCHAR(30) default '',           -- #417Retail Component SKU
--                 Line_Item2_04_Reserve01 NVARCHAR(30) default '',               -- #418ParentSKU
--                 Line_Item2_04_Reserve02 NVARCHAR(30) default '',               -- #419
--                 Line_Item2_04_Reserve03 NVARCHAR(30) default '',               -- #420
--                 Line_Item2_04_Reserve04 NVARCHAR(30) default '',               -- #421
--                 Line_Item2_04_Reserve05 NVARCHAR(30) default '',               -- #422
--                 Line_Item2_05_Style NVARCHAR(20) default '',                   -- #423Style
--          Line_Item2_05_Color NVARCHAR(10) default '',                   -- #424Color
--                 Line_Item2_05_Measurement NVARCHAR(5) default '',              -- #425Measurement
--                 Line_Item2_05_Size_Description NVARCHAR(5) default '',         -- #426Size
--                 Line_Item2_05_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #427PACKDETAIL.Qty
--                 Line_Item2_05_ItemNum NVARCHAR(36) default '',                 -- #428Sku
--                 Line_Item2_05_RetailSKU NVARCHAR(20) default '',               -- #429Retail SKU
--                 Line_Item2_05_RetailCompSKU NVARCHAR(30) default '',           -- #430Retail Component SKU
--                 Line_Item2_05_Reserve01 NVARCHAR(30) default '',               -- #431ParentSKU
--                 Line_Item2_05_Reserve02 NVARCHAR(30) default '',               -- #432
--                 Line_Item2_05_Reserve03 NVARCHAR(30) default '',               -- #433
--                 Line_Item2_05_Reserve04 NVARCHAR(30) default '',               -- #434
--                 Line_Item2_05_Reserve05 NVARCHAR(30) default '',               -- #435
--                 Line_Item2_06_Style NVARCHAR(20) default '',                   -- #436Style
--                 Line_Item2_06_Color NVARCHAR(10) default '',                   -- #437Color
--                 Line_Item2_06_Measurement NVARCHAR(5) default '',              -- #438Measurement
--                 Line_Item2_06_Size_Description NVARCHAR(5) default '',         -- #439Size
--                 Line_Item2_06_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #440PACKDETAIL.Qty
--                 Line_Item2_06_ItemNum NVARCHAR(36) default '',                 -- #441Sku
--                 Line_Item2_06_RetailSKU NVARCHAR(20) default '',               -- #442Retail SKU
--                 Line_Item2_06_RetailCompSKU NVARCHAR(30) default '',           -- #443Retail Component SKU
--                 Line_Item2_06_Reserve01 NVARCHAR(30) default '',               -- #444ParentSKU
--                 Line_Item2_06_Reserve02 NVARCHAR(30) default '',               -- #445
--                 Line_Item2_06_Reserve03 NVARCHAR(30) default '',               -- #446
--                 Line_Item2_06_Reserve04 NVARCHAR(30) default '',               -- #447
--                 Line_Item2_06_Reserve05 NVARCHAR(30) default '',               -- #448
--                 Line_Item2_07_Style NVARCHAR(20) default '',                   -- #449Style
--                 Line_Item2_07_Color NVARCHAR(10) default '',                   -- #450Color
--                 Line_Item2_07_Measurement NVARCHAR(5) default '',              -- #451Measurement
--                 Line_Item2_07_Size_Description NVARCHAR(5) default '',         -- #452Size
--                 Line_Item2_07_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #453PACKDETAIL.Qty
--                 Line_Item2_07_ItemNum NVARCHAR(36) default '',                 -- #454Sku
--                 Line_Item2_07_RetailSKU NVARCHAR(20) default '',               -- #455Retail SKU
--                 Line_Item2_07_RetailCompSKU NVARCHAR(30) default '',           -- #456Retail Component SKU
--                 Line_Item2_07_Reserve01 NVARCHAR(30) default '',               -- #457ParentSKU
--                 Line_Item2_07_Reserve02 NVARCHAR(30) default '',               -- #458
--                 Line_Item2_07_Reserve03 NVARCHAR(30) default '',               -- #459
--                 Line_Item2_07_Reserve04 NVARCHAR(30) default '',               -- #460
--                 Line_Item2_07_Reserve05 NVARCHAR(30) default '',               -- #461
--                 Line_Item2_08_Style NVARCHAR(20) default '',                   -- #462Style
--                 Line_Item2_08_Color NVARCHAR(10) default '',                   -- #463Color
--                 Line_Item2_08_Measurement NVARCHAR(5) default '',              -- #464Measurement
--                 Line_Item2_08_Size_Description NVARCHAR(5) default '',         -- #465Size
--                 Line_Item2_08_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #466PACKDETAIL.Qty
--                 Line_Item2_08_ItemNum NVARCHAR(36) default '',                 -- #467Sku
--                 Line_Item2_08_RetailSKU NVARCHAR(20) default '',               -- #468Retail SKU
--                 Line_Item2_08_RetailCompSKU NVARCHAR(30) default '',           -- #469Retail Component SKU
--                 Line_Item2_08_Reserve01 NVARCHAR(30) default '',               -- #470ParentSKU
--                 Line_Item2_08_Reserve02 NVARCHAR(30) default '',               -- #471
--                 Line_Item2_08_Reserve03 NVARCHAR(30) default '',               -- #472
--                 Line_Item2_08_Reserve04 NVARCHAR(30) default '',               -- #473
--                 Line_Item2_08_Reserve05 NVARCHAR(30) default '',               -- #474
--                 Line_Item2_09_Style NVARCHAR(20) default '',                   -- #475Style
--                 Line_Item2_09_Color NVARCHAR(10) default '',                   -- #476Color
--                 Line_Item2_09_Measurement NVARCHAR(5) default '',              -- #477Measurement
--                 Line_Item2_09_Size_Description NVARCHAR(5) default '',         -- #478Size
--                 Line_Item2_09_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #479PACKDETAIL.Qty
--                 Line_Item2_09_ItemNum NVARCHAR(36) default '',                 -- #480Sku
--                 Line_Item2_09_RetailSKU NVARCHAR(20) default '',               -- #481Retail SKU
--                 Line_Item2_09_RetailCompSKU NVARCHAR(30) default '',           -- #482Retail Component SKU
--                 Line_Item2_09_Reserve01 NVARCHAR(30) default '',               -- #483ParentSKU
--                 Line_Item2_09_Reserve02 NVARCHAR(30) default '',               -- #484
--                 Line_Item2_09_Reserve03 NVARCHAR(30) default '',               -- #485
--                 Line_Item2_09_Reserve04 NVARCHAR(30) default '',               -- #486
--                 Line_Item2_09_Reserve05 NVARCHAR(30) default '',               -- #487
--                 Line_Item2_10_Style NVARCHAR(20) default '',                   -- #488Style
--                 Line_Item2_10_Color NVARCHAR(10) default '',                   -- #489Color
--                 Line_Item2_10_Measurement NVARCHAR(5) default '',              -- #490Measurement
--                 Line_Item2_10_Size_Description NVARCHAR(5) default '',         -- #491Size
--                 Line_Item2_10_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #492PACKDETAIL.Qty
--                 Line_Item2_10_ItemNum NVARCHAR(36) default '',                 -- #493Sku
--                 Line_Item2_10_RetailSKU NVARCHAR(20) default '',               -- #494Retail SKU
--                 Line_Item2_10_RetailCompSKU NVARCHAR(30) default '',           -- #495Retail Component SKU
--                 Line_Item2_10_Reserve01 NVARCHAR(30) default '',               -- #496ParentSKU
--                 Line_Item2_10_Reserve02 NVARCHAR(30) default '',               -- #497
--                 Line_Item2_10_Reserve03 NVARCHAR(30) default '',               -- #498
--                 Line_Item2_10_Reserve04 NVARCHAR(30) default '',               -- #499
--                 Line_Item2_10_Reserve05 NVARCHAR(30) default '',               -- #500
--                 Line_Item2_11_Style NVARCHAR(20) default '',                   -- #501Style
--                 Line_Item2_11_Color NVARCHAR(10) default '',                   -- #502Color
--                 Line_Item2_11_Measurement NVARCHAR(5) default '',              -- #503Measurement
--                 Line_Item2_11_Size_Description NVARCHAR(5) default '',         -- #504Size
--                 Line_Item2_11_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #505PACKDETAIL.Qty
--                 Line_Item2_11_ItemNum NVARCHAR(36) default '',                 -- #506Sku
--                 Line_Item2_11_RetailSKU NVARCHAR(20) default '',               -- #507Retail SKU
--                 Line_Item2_11_RetailCompSKU NVARCHAR(30) default '',           -- #508Retail Component SKU
--                 Line_Item2_11_Reserve01 NVARCHAR(30) default '',               -- #509ParentSKU
--                 Line_Item2_11_Reserve02 NVARCHAR(30) default '',               -- #510
--                 Line_Item2_11_Reserve03 NVARCHAR(30) default '',               -- #511
--                 Line_Item2_11_Reserve04 NVARCHAR(30) default '',               -- #512
--                 Line_Item2_11_Reserve05 NVARCHAR(30) default '',               -- #513
--                 Line_Item2_12_Style NVARCHAR(20) default '',                   -- #514Style
--                 Line_Item2_12_Color NVARCHAR(10) default '',                   -- #515Color
--                 Line_Item2_12_Measurement NVARCHAR(5) default '',              -- #516Measurement
--                 Line_Item2_12_Size_Description NVARCHAR(5) default '',         -- #517Size
--                 Line_Item2_12_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #518PACKDETAIL.Qty
--                 Line_Item2_12_ItemNum NVARCHAR(36) default '',                 -- #519Sku
--                 Line_Item2_12_RetailSKU NVARCHAR(20) default '',               -- #520Retail SKU
--                 Line_Item2_12_RetailCompSKU NVARCHAR(30) default '',           -- #521Retail Component SKU
--                 Line_Item2_12_Reserve01 NVARCHAR(30) default '',               -- #522ParentSKU
--                 Line_Item2_12_Reserve02 NVARCHAR(30) default '',               -- #523
--                 Line_Item2_12_Reserve03 NVARCHAR(30) default '',               -- #524
--                 Line_Item2_12_Reserve04 NVARCHAR(30) default '',               -- #525
--                 Line_Item2_12_Reserve05 NVARCHAR(30) default '',               -- #526
--                 Line_Item2_13_Style NVARCHAR(20) default '',                   -- #527Style
--                 Line_Item2_13_Color NVARCHAR(10) default '',                   -- #528Color
--                 Line_Item2_13_Measurement NVARCHAR(5) default '',              -- #529Measurement
--                 Line_Item2_13_Size_Description NVARCHAR(5) default '',         -- #530Size
--                 Line_Item2_13_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #531PACKDETAIL.Qty
--                 Line_Item2_13_ItemNum NVARCHAR(36) default '',                 -- #532Sku
--                 Line_Item2_13_RetailSKU NVARCHAR(20) default '',               -- #533Retail SKU
--                 Line_Item2_13_RetailCompSKU NVARCHAR(30) default '',           -- #534Retail Component SKU
--                 Line_Item2_13_Reserve01 NVARCHAR(30) default '',               -- #535ParentSKU
--                 Line_Item2_13_Reserve02 NVARCHAR(30) default '',               -- #536
--                 Line_Item2_13_Reserve03 NVARCHAR(30) default '',               -- #537
--                 Line_Item2_13_Reserve04 NVARCHAR(30) default '',               -- #538
--                 Line_Item2_13_Reserve05 NVARCHAR(30) default '',               -- #539
--                 Line_Item2_14_Style NVARCHAR(20) default '',                   -- #540Style
--                 Line_Item2_14_Color NVARCHAR(10) default '',                   -- #541Color
--                 Line_Item2_14_Measurement NVARCHAR(5) default '',              -- #542Measurement
--                 Line_Item2_14_Size_Description NVARCHAR(5) default '',         -- #543Size
--                 Line_Item2_14_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #544PACKDETAIL.Qty
--                 Line_Item2_14_ItemNum NVARCHAR(36) default '',                 -- #545Sku
--                 Line_Item2_14_RetailSKU NVARCHAR(20) default '',               -- #546Retail SKU
--                 Line_Item2_14_RetailCompSKU NVARCHAR(30) default '',           -- #547Retail Component SKU
--                 Line_Item2_14_Reserve01 NVARCHAR(30) default '',               -- #548ParentSKU
--                 Line_Item2_14_Reserve02 NVARCHAR(30) default '',               -- #549
--                 Line_Item2_14_Reserve03 NVARCHAR(30) default '',               -- #550
--                 Line_Item2_14_Reserve04 NVARCHAR(30) default '',               -- #551
--                 Line_Item2_14_Reserve05 NVARCHAR(30) default '',               -- #552
--                 Line_Item2_15_Style NVARCHAR(20) default '',                   -- #553Style
--                 Line_Item2_15_Color NVARCHAR(10) default '',                   -- #554Color
--                 Line_Item2_15_Measurement NVARCHAR(5) default '',              -- #555Measurement
--                 Line_Item2_15_Size_Description NVARCHAR(5) default '',         -- #556Size
--                 Line_Item2_15_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #557PACKDETAIL.Qty
--                 Line_Item2_15_ItemNum NVARCHAR(36) default '',                 -- #558Sku
--                 Line_Item2_15_RetailSKU NVARCHAR(20) default '',               -- #559Retail SKU
--                 Line_Item2_15_RetailCompSKU NVARCHAR(30) default '',           -- #560Retail Component SKU
--                 Line_Item2_15_Reserve01 NVARCHAR(30) default '',               -- #561ParentSKU
--                 Line_Item2_15_Reserve02 NVARCHAR(30) default '',               -- #562
--                 Line_Item2_15_Reserve03 NVARCHAR(30) default '',               -- #563
--                 Line_Item2_15_Reserve04 NVARCHAR(30) default '',               -- #564
--                 Line_Item2_15_Reserve05 NVARCHAR(30) default '',               -- #565
--                 Line_Item2_16_Style NVARCHAR(20) default '',                   -- #566Style
--                 Line_Item2_16_Color NVARCHAR(10) default '',                   -- #567Color
--                 Line_Item2_16_Measurement NVARCHAR(5) default '',              -- #568Measurement
--                 Line_Item2_16_Size_Description NVARCHAR(5) default '',         -- #569Size
--                 Line_Item2_16_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #570PACKDETAIL.Qty
--                 Line_Item2_16_ItemNum NVARCHAR(36) default '',                 -- #571Sku
--                 Line_Item2_16_RetailSKU NVARCHAR(20) default '',               -- #572Retail SKU
--                 Line_Item2_16_RetailCompSKU NVARCHAR(30) default '',           -- #573Retail Component SKU
--                 Line_Item2_16_Reserve01 NVARCHAR(30) default '',               -- #574ParentSKU
--                 Line_Item2_16_Reserve02 NVARCHAR(30) default '',               -- #575
--                 Line_Item2_16_Reserve03 NVARCHAR(30) default '',               -- #576
--                 Line_Item2_16_Reserve04 NVARCHAR(30) default '',               -- #577
--                 Line_Item2_16_Reserve05 NVARCHAR(30) default '',               -- #578
--                 Line_Item2_17_Style NVARCHAR(20) default '',                   -- #579Style
--                 Line_Item2_17_Color NVARCHAR(10) default '',                   -- #580Color
--                 Line_Item2_17_Measurement NVARCHAR(5) default '',              -- #581Measurement
--                 Line_Item2_17_Size_Description NVARCHAR(5) default '',         -- #582Size
--                 Line_Item2_17_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #583PACKDETAIL.Qty
--                 Line_Item2_17_ItemNum NVARCHAR(36) default '',                 -- #584Sku
--                 Line_Item2_17_RetailSKU NVARCHAR(20) default '',               -- #585Retail SKU
--                 Line_Item2_17_RetailCompSKU NVARCHAR(30) default '',           -- #586Retail Component SKU
--                 Line_Item2_17_Reserve01 NVARCHAR(30) default '',               -- #587ParentSKU
--                 Line_Item2_17_Reserve02 NVARCHAR(30) default '',               -- #588
--                 Line_Item2_17_Reserve03 NVARCHAR(30) default '',               -- #589
--                 Line_Item2_17_Reserve04 NVARCHAR(30) default '',               -- #590
--                 Line_Item2_17_Reserve05 NVARCHAR(30) default '',               -- #591
--                 Line_Item2_18_Style NVARCHAR(20) default '',                   -- #592Style
--                 Line_Item2_18_Color NVARCHAR(10) default '',                   -- #593Color
--                 Line_Item2_18_Measurement NVARCHAR(5) default '',              -- #594Measurement
--                 Line_Item2_18_Size_Description NVARCHAR(5) default '',         -- #595Size
--                 Line_Item2_18_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #596PACKDETAIL.Qty
--                 Line_Item2_18_ItemNum NVARCHAR(36) default '',                 -- #597Sku
--                 Line_Item2_18_RetailSKU NVARCHAR(20) default '',               -- #598Retail SKU
--                 Line_Item2_18_RetailCompSKU NVARCHAR(30) default '',           -- #599Retail Component SKU
--                 Line_Item2_18_Reserve01 NVARCHAR(30) default '',               -- #600ParentSKU
--                 Line_Item2_18_Reserve02 NVARCHAR(30) default '',               -- #601
--                 Line_Item2_18_Reserve03 NVARCHAR(30) default '',               -- #602
--                 Line_Item2_18_Reserve04 NVARCHAR(30) default '',               -- #603
--                 Line_Item2_18_Reserve05 NVARCHAR(30) default '',               -- #604
--                 Line_Item2_19_Style NVARCHAR(20) default '',                   -- #605Style
--                 Line_Item2_19_Color NVARCHAR(10) default '',                   -- #606Color
--                 Line_Item2_19_Measurement NVARCHAR(5) default '',              -- #607Measurement
--                 Line_Item2_19_Size_Description NVARCHAR(5) default '',         -- #608Size
--                 Line_Item2_19_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #609PACKDETAIL.Qty
--                 Line_Item2_19_ItemNum NVARCHAR(36) default '',                 -- #610Sku
--                 Line_Item2_19_RetailSKU NVARCHAR(20) default '',               -- #611Retail SKU
--                 Line_Item2_19_RetailCompSKU NVARCHAR(30) default '',           -- #612Retail Component SKU
--                 Line_Item2_19_Reserve01 NVARCHAR(30) default '',               -- #613ParentSKU
--                 Line_Item2_19_Reserve02 NVARCHAR(30) default '',               -- #614
--                 Line_Item2_19_Reserve03 NVARCHAR(30) default '',               -- #615
--                 Line_Item2_19_Reserve04 NVARCHAR(30) default '',               -- #616
--                 Line_Item2_19_Reserve05 NVARCHAR(30) default '',               -- #617
--                 Line_Item2_20_Style NVARCHAR(20) default '',                   -- #618Style
--                 Line_Item2_20_Color NVARCHAR(10) default '',                   -- #619Color
--                 Line_Item2_20_Measurement NVARCHAR(5) default '',              -- #620Measurement
--                 Line_Item2_20_Size_Description NVARCHAR(5) default '',         -- #621Size
--                 Line_Item2_20_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #622PACKDETAIL.Qty
--                 Line_Item2_20_ItemNum NVARCHAR(36) default '',                 -- #623Sku
--                 Line_Item2_20_RetailSKU NVARCHAR(20) default '',               -- #624Retail SKU
--                 Line_Item2_20_RetailCompSKU NVARCHAR(30) default '',           -- #625Retail Component SKU
--                 Line_Item2_20_Reserve01 NVARCHAR(30) default '',               -- #626ParentSKU
--                 Line_Item2_20_Reserve02 NVARCHAR(30) default '',               -- #627
--                 Line_Item2_20_Reserve03 NVARCHAR(30) default '',               -- #628
--                 Line_Item2_20_Reserve04 NVARCHAR(30) default '',               -- #629
--                 Line_Item2_20_Reserve05 NVARCHAR(30) default '',               -- #630
--                 Line_Item2_21_Style NVARCHAR(20) default '',                   -- #631Style
--                 Line_Item2_21_Color NVARCHAR(10) default '',                   -- #632Color
--                 Line_Item2_21_Measurement NVARCHAR(5) default '',              -- #633Measurement
--                 Line_Item2_21_Size_Description NVARCHAR(5) default '',         -- #634Size
--                 Line_Item2_21_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #635PACKDETAIL.Qty
--                 Line_Item2_21_ItemNum NVARCHAR(36) default '',                 -- #636Sku
--                 Line_Item2_21_RetailSKU NVARCHAR(20) default '',               -- #637Retail SKU
--                 Line_Item2_21_RetailCompSKU NVARCHAR(30) default '',           -- #638Retail Component SKU
--                 Line_Item2_21_Reserve01 NVARCHAR(30) default '',               -- #639ParentSKU
--                 Line_Item2_21_Reserve02 NVARCHAR(30) default '',               -- #640
--                 Line_Item2_21_Reserve03 NVARCHAR(30) default '',               -- #641
--                 Line_Item2_21_Reserve04 NVARCHAR(30) default '',               -- #642
--                 Line_Item2_21_Reserve05 NVARCHAR(30) default '',               -- #643
--                 Line_Item2_22_Style NVARCHAR(20) default '',                   -- #644Style
--                 Line_Item2_22_Color NVARCHAR(10) default '',                   -- #645Color
--                 Line_Item2_22_Measurement NVARCHAR(5) default '',              -- #646Measurement
--                 Line_Item2_22_Size_Description NVARCHAR(5) default '',         -- #647Size
--                 Line_Item2_22_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #648PACKDETAIL.Qty
--                 Line_Item2_22_ItemNum NVARCHAR(36) default '',                 -- #649Sku
--                 Line_Item2_22_RetailSKU NVARCHAR(20) default '',               -- #650Retail SKU
--                 Line_Item2_22_RetailCompSKU NVARCHAR(30) default '',           -- #651Retail Component SKU
--                 Line_Item2_22_Reserve01 NVARCHAR(30) default '',               -- #652ParentSKU
--                 Line_Item2_22_Reserve02 NVARCHAR(30) default '',               -- #653
--                 Line_Item2_22_Reserve03 NVARCHAR(30) default '',               -- #654
--                 Line_Item2_22_Reserve04 NVARCHAR(30) default '',               -- #655
--                 Line_Item2_22_Reserve05 NVARCHAR(30) default '',               -- #656
--                 Line_Item2_23_Style NVARCHAR(20) default '',                   -- #657Style
--                 Line_Item2_23_Color NVARCHAR(10) default '',                   -- #658Color
--                 Line_Item2_23_Measurement NVARCHAR(5) default '',              -- #659Measurement
--                 Line_Item2_23_Size_Description NVARCHAR(5) default '',         -- #660Size
--                 Line_Item2_23_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #661PACKDETAIL.Qty
--                 Line_Item2_23_ItemNum NVARCHAR(36) default '',                 -- #662Sku
--                 Line_Item2_23_RetailSKU NVARCHAR(20) default '',               -- #663Retail SKU
--                 Line_Item2_23_RetailCompSKU NVARCHAR(30) default '',           -- #664Retail Component SKU
--                 Line_Item2_23_Reserve01 NVARCHAR(30) default '',               -- #665ParentSKU
--                 Line_Item2_23_Reserve02 NVARCHAR(30) default '',               -- #666
--                 Line_Item2_23_Reserve03 NVARCHAR(30) default '',               -- #667
--                 Line_Item2_23_Reserve04 NVARCHAR(30) default '',               -- #668
--                 Line_Item2_23_Reserve05 NVARCHAR(30) default '',               -- #669
--                 Line_Item2_24_Style NVARCHAR(20) default '',                   -- #670Style
--                 Line_Item2_24_Color NVARCHAR(10) default '',                   -- #671Color
--                 Line_Item2_24_Measurement NVARCHAR(5) default '',              -- #672Measurement
--                 Line_Item2_24_Size_Description NVARCHAR(5) default '',         -- #673Size
--                 Line_Item2_24_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #674PACKDETAIL.Qty
--                 Line_Item2_24_ItemNum NVARCHAR(36) default '',                 -- #675Sku
--                 Line_Item2_24_RetailSKU NVARCHAR(20) default '',               -- #676Retail SKU
--                 Line_Item2_24_RetailCompSKU NVARCHAR(30) default '',           -- #677Retail Component SKU
--                 Line_Item2_24_Reserve01 NVARCHAR(30) default '',               -- #678ParentSKU
--                 Line_Item2_24_Reserve02 NVARCHAR(30) default '',               -- #679
--                 Line_Item2_24_Reserve03 NVARCHAR(30) default '',               -- #680
--                 Line_Item2_24_Reserve04 NVARCHAR(30) default '',               -- #681
--                 Line_Item2_24_Reserve05 NVARCHAR(30) default '',               -- #682
--                 Line_Item2_25_Style NVARCHAR(20) default '',                   -- #683Style
--                 Line_Item2_25_Color NVARCHAR(10) default '',                   -- #684Color
--                 Line_Item2_25_Measurement NVARCHAR(5) default '',              -- #685Measurement
--                 Line_Item2_25_Size_Description NVARCHAR(5) default '',         -- #686Size
--                 Line_Item2_25_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #687PACKDETAIL.Qty
--                 Line_Item2_25_ItemNum NVARCHAR(36) default '',                 -- #688Sku
--                 Line_Item2_25_RetailSKU NVARCHAR(20) default '',               -- #689Retail SKU
--                 Line_Item2_25_RetailCompSKU NVARCHAR(30) default '',           -- #690Retail Component SKU
--                 Line_Item2_25_Reserve01 NVARCHAR(30) default '',               -- #691ParentSKU
--                 Line_Item2_25_Reserve02 NVARCHAR(30) default '',               -- #692
--                 Line_Item2_25_Reserve03 NVARCHAR(30) default '',               -- #693
--                 Line_Item2_25_Reserve04 NVARCHAR(30) default '',               -- #694
--                 Line_Item2_25_Reserve05 NVARCHAR(30) default '',               -- #695
--                 Line_Item2_26_Style NVARCHAR(20) default '',                   -- #696Style
--                 Line_Item2_26_Color NVARCHAR(10) default '',                   -- #697Color
--                 Line_Item2_26_Measurement NVARCHAR(5) default '',              -- #698Measurement
--                 Line_Item2_26_Size_Description NVARCHAR(5) default '',         -- #699Size
--                 Line_Item2_26_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #700PACKDETAIL.Qty
--                 Line_Item2_26_ItemNum NVARCHAR(36) default '',                 -- #701Sku
--                 Line_Item2_26_RetailSKU NVARCHAR(20) default '',               -- #702Retail SKU
--                 Line_Item2_26_RetailCompSKU NVARCHAR(30) default '',           -- #703Retail Component SKU
--                 Line_Item2_26_Reserve01 NVARCHAR(30) default '',               -- #704ParentSKU
--                 Line_Item2_26_Reserve02 NVARCHAR(30) default '',               -- #705
--                 Line_Item2_26_Reserve03 NVARCHAR(30) default '',               -- #706
--                 Line_Item2_26_Reserve04 NVARCHAR(30) default '',               -- #707
--                 Line_Item2_26_Reserve05 NVARCHAR(30) default '',               -- #708
--                 Line_Item2_27_Style NVARCHAR(20) default '',                   -- #709Style
--                 Line_Item2_27_Color NVARCHAR(10) default '',                   -- #710Color
--                 Line_Item2_27_Measurement NVARCHAR(5) default '',              -- #711Measurement
--                 Line_Item2_27_Size_Description NVARCHAR(5) default '',         -- #712Size
--                 Line_Item2_27_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #713PACKDETAIL.Qty
--                 Line_Item2_27_ItemNum NVARCHAR(36) default '',                 -- #714Sku
--                 Line_Item2_27_RetailSKU NVARCHAR(20) default '',               -- #715Retail SKU
--                 Line_Item2_27_RetailCompSKU NVARCHAR(30) default '',           -- #716Retail Component SKU
--                 Line_Item2_27_Reserve01 NVARCHAR(30) default '',               -- #717ParentSKU
--                 Line_Item2_27_Reserve02 NVARCHAR(30) default '',               -- #718
--                 Line_Item2_27_Reserve03 NVARCHAR(30) default '',               -- #719
--                 Line_Item2_27_Reserve04 NVARCHAR(30) default '',               -- #720
--                 Line_Item2_27_Reserve05 NVARCHAR(30) default '',               -- #721
--                 Line_Item2_28_Style NVARCHAR(20) default '',                   -- #722Style
--                 Line_Item2_28_Color NVARCHAR(10) default '',                   -- #723Color
--                 Line_Item2_28_Measurement NVARCHAR(5) default '',              -- #724Measurement
--                 Line_Item2_28_Size_Description NVARCHAR(5) default '',         -- #725Size
--                 Line_Item2_28_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #726PACKDETAIL.Qty
--                 Line_Item2_28_ItemNum NVARCHAR(36) default '',                 -- #727Sku
--                 Line_Item2_28_RetailSKU NVARCHAR(20) default '',               -- #728Retail SKU
--                 Line_Item2_28_RetailCompSKU NVARCHAR(30) default '',           -- #729Retail Component SKU
--                 Line_Item2_28_Reserve01 NVARCHAR(30) default '',               -- #730ParentSKU
--                 Line_Item2_28_Reserve02 NVARCHAR(30) default '',               -- #731
--                 Line_Item2_28_Reserve03 NVARCHAR(30) default '',               -- #732
--                 Line_Item2_28_Reserve04 NVARCHAR(30) default '',               -- #733
--                 Line_Item2_28_Reserve05 NVARCHAR(30) default '',               -- #734
--                 Line_Item2_29_Style NVARCHAR(20) default '',                   -- #735Style
--                 Line_Item2_29_Color NVARCHAR(10) default '',                   -- #736Color
--                 Line_Item2_29_Measurement NVARCHAR(5) default '',              -- #737Measurement
--                 Line_Item2_29_Size_Description NVARCHAR(5) default '',         -- #738Size
--                 Line_Item2_29_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #739PACKDETAIL.Qty
--                 Line_Item2_29_ItemNum NVARCHAR(36) default '',                 -- #740Sku
--                 Line_Item2_29_RetailSKU NVARCHAR(20) default '',               -- #741Retail SKU
--                 Line_Item2_29_RetailCompSKU NVARCHAR(30) default '',           -- #742Retail Component SKU
--                 Line_Item2_29_Reserve01 NVARCHAR(30) default '',               -- #743ParentSKU
--                 Line_Item2_29_Reserve02 NVARCHAR(30) default '',               -- #744
--                 Line_Item2_29_Reserve03 NVARCHAR(30) default '',               -- #745
--                 Line_Item2_29_Reserve04 NVARCHAR(30) default '',               -- #746
--                 Line_Item2_29_Reserve05 NVARCHAR(30) default '',               -- #747
--                 Line_Item2_30_Style NVARCHAR(20) default '',                   -- #748Style
--                 Line_Item2_30_Color NVARCHAR(10) default '',                   -- #749Color
--                 Line_Item2_30_Measurement NVARCHAR(5) default '',              -- #750Measurement
--                 Line_Item2_30_Size_Description NVARCHAR(5) default '',         -- #751Size
--                 Line_Item2_30_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #752PACKDETAIL.Qty
--                 Line_Item2_30_ItemNum NVARCHAR(36) default '',                 -- #753Sku
--                 Line_Item2_30_RetailSKU NVARCHAR(20) default '',               -- #754Retail SKU
--                 Line_Item2_30_RetailCompSKU NVARCHAR(30) default '',           -- #755Retail Component SKU
--                 Line_Item2_30_Reserve01 NVARCHAR(30) default '',               -- #756ParentSKU
--                 Line_Item2_30_Reserve02 NVARCHAR(30) default '',               -- #757
--                 Line_Item2_30_Reserve03 NVARCHAR(30) default '',               -- #758
--                 Line_Item2_30_Reserve04 NVARCHAR(30) default '',               -- #759
--                 Line_Item2_30_Reserve05 NVARCHAR(30) default '',               -- #760
--                 Line_Item2_31_Style NVARCHAR(20) default '',                   -- #761Style
--                 Line_Item2_31_Color NVARCHAR(10) default '',                   -- #762Color
--                 Line_Item2_31_Measurement NVARCHAR(5) default '',              -- #763Measurement
--                 Line_Item2_31_Size_Description NVARCHAR(5) default '',         -- #764Size
--                 Line_Item2_31_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #765PACKDETAIL.Qty
--                 Line_Item2_31_ItemNum NVARCHAR(36) default '',                 -- #766Sku
--                 Line_Item2_31_RetailSKU NVARCHAR(20) default '',               -- #767Retail SKU
--                 Line_Item2_31_RetailCompSKU NVARCHAR(30) default '',           -- #768Retail Component SKU
--                 Line_Item2_31_Reserve01 NVARCHAR(30) default '',               -- #769ParentSKU
--                 Line_Item2_31_Reserve02 NVARCHAR(30) default '',               -- #770
--                 Line_Item2_31_Reserve03 NVARCHAR(30) default '',               -- #771
--                 Line_Item2_31_Reserve04 NVARCHAR(30) default '',               -- #772
--                 Line_Item2_31_Reserve05 NVARCHAR(30) default '',               -- #773
--                 Line_Item2_32_Style NVARCHAR(20) default '',                   -- #774Style
--                 Line_Item2_32_Color NVARCHAR(10) default '',                   -- #775Color
--                 Line_Item2_32_Measurement NVARCHAR(5) default '',              -- #776Measurement
--                 Line_Item2_32_Size_Description NVARCHAR(5) default '',         -- #777Size
--                 Line_Item2_32_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #778PACKDETAIL.Qty
--                 Line_Item2_32_ItemNum NVARCHAR(36) default '',                 -- #779Sku
--                 Line_Item2_32_RetailSKU NVARCHAR(20) default '',               -- #780Retail SKU
--                 Line_Item2_32_RetailCompSKU NVARCHAR(30) default '',           -- #781Retail Component SKU
--                 Line_Item2_32_Reserve01 NVARCHAR(30) default '',               -- #782ParentSKU
--                 Line_Item2_32_Reserve02 NVARCHAR(30) default '',               -- #783
--                 Line_Item2_32_Reserve03 NVARCHAR(30) default '',               -- #784
--                 Line_Item2_32_Reserve04 NVARCHAR(30) default '',               -- #785
--                 Line_Item2_32_Reserve05 NVARCHAR(30) default '',               -- #786
--                 Line_Item2_33_Style NVARCHAR(20) default '',                   -- #787Style
--                 Line_Item2_33_Color NVARCHAR(10) default '',                   -- #788Color
--                 Line_Item2_33_Measurement NVARCHAR(5) default '',              -- #789Measurement
--                 Line_Item2_33_Size_Description NVARCHAR(5) default '',         -- #790Size
--                 Line_Item2_33_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #791PACKDETAIL.Qty
--                 Line_Item2_33_ItemNum NVARCHAR(36) default '',                 -- #792Sku
--                 Line_Item2_33_RetailSKU NVARCHAR(20) default '',           -- #793Retail SKU
--                 Line_Item2_33_RetailCompSKU NVARCHAR(30) default '',           -- #794Retail Component SKU
--                 Line_Item2_33_Reserve01 NVARCHAR(30) default '',               -- #795ParentSKU
--                 Line_Item2_33_Reserve02 NVARCHAR(30) default '',               -- #796
--                 Line_Item2_33_Reserve03 NVARCHAR(30) default '',               -- #797
--                 Line_Item2_33_Reserve04 NVARCHAR(30) default '',               -- #798
--                 Line_Item2_33_Reserve05 NVARCHAR(30) default '',               -- #799
--                 Line_Item2_34_Style NVARCHAR(20) default '',                   -- #800Style
--                 Line_Item2_34_Color NVARCHAR(10) default '',                   -- #801Color
--                 Line_Item2_34_Measurement NVARCHAR(5) default '',              -- #802Measurement
--                 Line_Item2_34_Size_Description NVARCHAR(5) default '',         -- #803Size
--                 Line_Item2_34_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #804PACKDETAIL.Qty
--                 Line_Item2_34_ItemNum NVARCHAR(36) default '',                 -- #805Sku
--                 Line_Item2_34_RetailSKU NVARCHAR(20) default '',               -- #806Retail SKU
--                 Line_Item2_34_RetailCompSKU NVARCHAR(30) default '',           -- #807Retail Component SKU
--                 Line_Item2_34_Reserve01 NVARCHAR(30) default '',               -- #808ParentSKU
--                 Line_Item2_34_Reserve02 NVARCHAR(30) default '',               -- #809
--                 Line_Item2_34_Reserve03 NVARCHAR(30) default '',               -- #810
--                 Line_Item2_34_Reserve04 NVARCHAR(30) default '',               -- #811
--                 Line_Item2_34_Reserve05 NVARCHAR(30) default '',               -- #812
--                 Line_Item2_35_Style NVARCHAR(20) default '',                   -- #813Style
--                 Line_Item2_35_Color NVARCHAR(10) default '',                   -- #814Color
--                 Line_Item2_35_Measurement NVARCHAR(5) default '',              -- #815Measurement
--                 Line_Item2_35_Size_Description NVARCHAR(5) default '',         -- #816Size
--                 Line_Item2_35_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #817PACKDETAIL.Qty
--                 Line_Item2_35_ItemNum NVARCHAR(36) default '',                 -- #818Sku
--                 Line_Item2_35_RetailSKU NVARCHAR(20) default '',               -- #819Retail SKU
--                 Line_Item2_35_RetailCompSKU NVARCHAR(30) default '',           -- #820Retail Component SKU
--                 Line_Item2_35_Reserve01 NVARCHAR(30) default '',               -- #821ParentSKU
--                 Line_Item2_35_Reserve02 NVARCHAR(30) default '',               -- #822
--                 Line_Item2_35_Reserve03 NVARCHAR(30) default '',               -- #823
--                 Line_Item2_35_Reserve04 NVARCHAR(30) default '',               -- #824
--                 Line_Item2_35_Reserve05 NVARCHAR(30) default '',               -- #825
--                 Line_Item2_36_Style NVARCHAR(20) default '',                   -- #826 Style
--                 Line_Item2_36_Color NVARCHAR(10) default '',                   -- #827 Color
--                 Line_Item2_36_Measurement NVARCHAR(5) default '',              -- #828 Measurement
--                 Line_Item2_36_Size_Description NVARCHAR(5) default '',         -- #829 Size
--                 Line_Item2_36_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #830 PACKDETAIL.Qty
--                 Line_Item2_36_ItemNum NVARCHAR(36) default '',                 -- #831 Sku
--                 Line_Item2_36_RetailSKU NVARCHAR(20) default '',               -- #832 Retail SKU
--                 Line_Item2_36_RetailCompSKU NVARCHAR(30) default '',           -- #833 Retail Component SKU
--                 Line_Item2_36_Reserve01 NVARCHAR(30) default '',               -- #834 ParentSKU
--                 Line_Item2_36_Reserve02 NVARCHAR(30) default '',               -- #835
--                 Line_Item2_36_Reserve03 NVARCHAR(30) default '',               -- #836
--                 Line_Item2_36_Reserve04 NVARCHAR(30) default '',               -- #837
--                 Line_Item2_36_Reserve05 NVARCHAR(30) default '',               -- #838
--                 Line_Item2_37_Style NVARCHAR(20) default '',                   -- #839 Style
--                 Line_Item2_37_Color NVARCHAR(10) default '',                   -- #840 Color
--                 Line_Item2_37_Measurement NVARCHAR(5) default '',              -- #841 Measurement
--                 Line_Item2_37_Size_Description NVARCHAR(5) default '',         -- #842 Size
--                 Line_Item2_37_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #843 PACKDETAIL.Qty
--                 Line_Item2_37_ItemNum NVARCHAR(36) default '',                 -- #844 Sku
--                 Line_Item2_37_RetailSKU NVARCHAR(20) default '',               -- #845 Retail SKU
--                 Line_Item2_37_RetailCompSKU NVARCHAR(30) default '',           -- #846 Retail Component SKU
--                 Line_Item2_37_Reserve01 NVARCHAR(30) default '',               -- #847 ParentSKU
--                 Line_Item2_37_Reserve02 NVARCHAR(30) default '',               -- #848
--                 Line_Item2_37_Reserve03 NVARCHAR(30) default '',               -- #849
--                 Line_Item2_37_Reserve04 NVARCHAR(30) default '',               -- #850
--                 Line_Item2_37_Reserve05 NVARCHAR(30) default '',               -- #851
--                 Line_Item2_38_Style NVARCHAR(20) default '',                   -- #852 Style
--                 Line_Item2_38_Color NVARCHAR(10) default '',                   -- #853 Color
--                 Line_Item2_38_Measurement NVARCHAR(5) default '',              -- #854 Measurement
--                 Line_Item2_38_Size_Description NVARCHAR(5) default '',         -- #855 Size
--                 Line_Item2_38_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #856 PACKDETAIL.Qty
--                 Line_Item2_38_ItemNum NVARCHAR(36) default '',                 -- #857 Sku
--                 Line_Item2_38_RetailSKU NVARCHAR(20) default '',               -- #858 Retail SKU
--                 Line_Item2_38_RetailCompSKU NVARCHAR(30) default '',           -- #859 Retail Component SKU
--                 Line_Item2_38_Reserve01 NVARCHAR(30) default '',               -- #860 ParentSKU
--                 Line_Item2_38_Reserve02 NVARCHAR(30) default '',               -- #861
--                 Line_Item2_38_Reserve03 NVARCHAR(30) default '',               -- #862
--                 Line_Item2_38_Reserve04 NVARCHAR(30) default '',               -- #863
--                 Line_Item2_38_Reserve05 NVARCHAR(30) default '',               -- #864
--                 Line_Item2_39_Style NVARCHAR(20) default '',                   -- #865 Style
--                 Line_Item2_39_Color NVARCHAR(10) default '',                   -- #866 Color
--   Line_Item2_39_Measurement NVARCHAR(5) default '',              -- #867 Measurement
--                 Line_Item2_39_Size_Description NVARCHAR(5) default '',         -- #868 Size
--                 Line_Item2_39_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #869 PACKDETAIL.Qty
--                 Line_Item2_39_ItemNum NVARCHAR(36) default '',                 -- #870 Sku
--                 Line_Item2_39_RetailSKU NVARCHAR(20) default '',               -- #871 Retail SKU
--                 Line_Item2_39_RetailCompSKU NVARCHAR(30) default '',           -- #872 Retail Component SKU
--                 Line_Item2_39_Reserve01 NVARCHAR(30) default '',               -- #873 ParentSKU
--                 Line_Item2_39_Reserve02 NVARCHAR(30) default '',               -- #874
--                 Line_Item2_39_Reserve03 NVARCHAR(30) default '',               -- #875
--                 Line_Item2_39_Reserve04 NVARCHAR(30) default '',               -- #876
--                 Line_Item2_39_Reserve05 NVARCHAR(30) default '',               -- #877
--                 Line_Item2_40_Style NVARCHAR(20) default '',                   -- #878 Style
--                 Line_Item2_40_Color NVARCHAR(10) default '',                   -- #879 Color
--                 Line_Item2_40_Measurement NVARCHAR(5) default '',              -- #880 Measurement
--                 Line_Item2_40_Size_Description NVARCHAR(5) default '',         -- #881 Size
--                 Line_Item2_40_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #882 PACKDETAIL.Qty
--                 Line_Item2_40_ItemNum NVARCHAR(36) default '',                 -- #883 Sku
--                 Line_Item2_40_RetailSKU NVARCHAR(20) default '',               -- #884 Retail SKU
--                 Line_Item2_40_RetailCompSKU NVARCHAR(30) default '',           -- #885 Retail Component SKU
--                 Line_Item2_40_Reserve01 NVARCHAR(30) default '',               -- #886 ParentSKU
--                 Line_Item2_40_Reserve02 NVARCHAR(30) default '',               -- #887
--                 Line_Item2_40_Reserve03 NVARCHAR(30) default '',               -- #888
--                 Line_Item2_40_Reserve04 NVARCHAR(30) default '',               -- #889
--                 Line_Item2_40_Reserve05 NVARCHAR(30) default '',               -- #890
--                 Line_Item2_41_Style NVARCHAR(20) default '',                   -- #891 Style
--                 Line_Item2_41_Color NVARCHAR(10) default '',                   -- #892 Color
--                 Line_Item2_41_Measurement NVARCHAR(5) default '',              -- #893 Measurement
--                 Line_Item2_41_Size_Description NVARCHAR(5) default '',         -- #894 Size
--                 Line_Item2_41_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #895 PACKDETAIL.Qty
--                 Line_Item2_41_ItemNum NVARCHAR(36) default '',                 -- #896 Sku
--                 Line_Item2_41_RetailSKU NVARCHAR(20) default '',               -- #897 Retail SKU
--                 Line_Item2_41_RetailCompSKU NVARCHAR(30) default '',           -- #898 Retail Component SKU
--                 Line_Item2_41_Reserve01 NVARCHAR(30) default '',               -- #899 ParentSKU
--                 Line_Item2_41_Reserve02 NVARCHAR(30) default '',               -- #900
--                 Line_Item2_41_Reserve03 NVARCHAR(30) default '',               -- #901
--                 Line_Item2_41_Reserve04 NVARCHAR(30) default '',               -- #902
-- Line_Item2_41_Reserve05 NVARCHAR(30) default '',               -- #903
--                 Line_Item2_42_Style NVARCHAR(20) default '',                   -- #904 Style
--                 Line_Item2_42_Color NVARCHAR(10) default '',                   -- #905 Color
--                 Line_Item2_42_Measurement NVARCHAR(5) default '',              -- #906 Measurement
--                 Line_Item2_42_Size_Description NVARCHAR(5) default '',         -- #907 Size
--                 Line_Item2_42_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #908 PACKDETAIL.Qty
--                 Line_Item2_42_ItemNum NVARCHAR(36) default '',                 -- #909 Sku
--                 Line_Item2_42_RetailSKU NVARCHAR(20) default '',               -- #910 Retail SKU
--                 Line_Item2_42_RetailCompSKU NVARCHAR(30) default '',           -- #911 Retail Component SKU
--                 Line_Item2_42_Reserve01 NVARCHAR(30) default '',               -- #912 ParentSKU
--                 Line_Item2_42_Reserve02 NVARCHAR(30) default '',               -- #913
--                 Line_Item2_42_Reserve03 NVARCHAR(30) default '',               -- #914
--                 Line_Item2_42_Reserve04 NVARCHAR(30) default '',               -- #915
--                 Line_Item2_42_Reserve05 NVARCHAR(30) default '',               -- #916
--                 Line_Item2_43_Style NVARCHAR(20) default '',                   -- #917 Style
--                 Line_Item2_43_Color NVARCHAR(10) default '',                   -- #918 Color
--                 Line_Item2_43_Measurement NVARCHAR(5) default '',              -- #919 Measurement
--                 Line_Item2_43_Size_Description NVARCHAR(5) default '',         -- #920 Size
--                 Line_Item2_43_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #921 PACKDETAIL.Qty
--                 Line_Item2_43_ItemNum NVARCHAR(36) default '',                 -- #922 Sku
--                 Line_Item2_43_RetailSKU NVARCHAR(20) default '',               -- #923 Retail SKU
--                 Line_Item2_43_RetailCompSKU NVARCHAR(30) default '',           -- #924 Retail Component SKU
--                 Line_Item2_43_Reserve01 NVARCHAR(30) default '',               -- #925 ParentSKU
--                 Line_Item2_43_Reserve02 NVARCHAR(30) default '',               -- #926
--                 Line_Item2_43_Reserve03 NVARCHAR(30) default '',               -- #927
--                 Line_Item2_43_Reserve04 NVARCHAR(30) default '',               -- #928
--                 Line_Item2_43_Reserve05 NVARCHAR(30) default '',               -- #929
--                 Line_Item2_44_Style NVARCHAR(20) default '',                   -- #930 Style
--                 Line_Item2_44_Color NVARCHAR(10) default '',                   -- #931 Color
--                 Line_Item2_44_Measurement NVARCHAR(5) default '',              -- #932 Measurement
--                 Line_Item2_44_Size_Description NVARCHAR(5) default '',         -- #933 Size
--                 Line_Item2_44_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #934 PACKDETAIL.Qty
--                 Line_Item2_44_ItemNum NVARCHAR(36) default '',                 -- #935 Sku
--                 Line_Item2_44_RetailSKU NVARCHAR(20) default '',               -- #936 Retail SKU
--                 Line_Item2_44_RetailCompSKU NVARCHAR(30) default '',           -- #937 Retail Component SKU
--                 Line_Item2_44_Reserve01 NVARCHAR(30) default '',               -- #938 ParentSKU
--         Line_Item2_44_Reserve02 NVARCHAR(30) default '',               -- #939
--                 Line_Item2_44_Reserve03 NVARCHAR(30) default '',               -- #940
--                 Line_Item2_44_Reserve04 NVARCHAR(30) default '',               -- #941
--                 Line_Item2_44_Reserve05 NVARCHAR(30) default '',               -- #942
--                 Line_Item2_45_Style NVARCHAR(20) default '',                   -- #943 Style
--                 Line_Item2_45_Color NVARCHAR(10) default '',                   -- #944 Color
--                 Line_Item2_45_Measurement NVARCHAR(5) default '',              -- #945 Measurement
--                 Line_Item2_45_Size_Description NVARCHAR(5) default '',         -- #946 Size
--                 Line_Item2_45_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #947 PACKDETAIL.Qty
--                 Line_Item2_45_ItemNum NVARCHAR(36) default '',                 -- #948 Sku
--                 Line_Item2_45_RetailSKU NVARCHAR(20) default '',               -- #949 Retail SKU
--                 Line_Item2_45_RetailCompSKU NVARCHAR(30) default '',           -- #950 Retail Component SKU
--                 Line_Item2_45_Reserve01 NVARCHAR(30) default '',               -- #951 ParentSKU
--                 Line_Item2_45_Reserve02 NVARCHAR(30) default '',               -- #952
--                 Line_Item2_45_Reserve03 NVARCHAR(30) default '',               -- #953
--                 Line_Item2_45_Reserve04 NVARCHAR(30) default '',               -- #954
--                 Line_Item2_45_Reserve05 NVARCHAR(30) default '',               -- #955
--                 Line_Item2_46_Style NVARCHAR(20) default '',                   -- #956 Style
--                 Line_Item2_46_Color NVARCHAR(10) default '',                   -- #957 Color
--                 Line_Item2_46_Measurement NVARCHAR(5) default '',              -- #958 Measurement
--                 Line_Item2_46_Size_Description NVARCHAR(5) default '',         -- #959 Size
--                 Line_Item2_46_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #960 PACKDETAIL.Qty
--                 Line_Item2_46_ItemNum NVARCHAR(36) default '',                 -- #961 Sku
--                 Line_Item2_46_RetailSKU NVARCHAR(20) default '',               -- #962 Retail SKU
--                 Line_Item2_46_RetailCompSKU NVARCHAR(30) default '',           -- #963 Retail Component SKU
--                 Line_Item2_46_Reserve01 NVARCHAR(30) default '',               -- #964 ParentSKU
--                 Line_Item2_46_Reserve02 NVARCHAR(30) default '',               -- #965
--                 Line_Item2_46_Reserve03 NVARCHAR(30) default '',               -- #966
--                 Line_Item2_46_Reserve04 NVARCHAR(30) default '',               -- #967
--                 Line_Item2_46_Reserve05 NVARCHAR(30) default '',               -- #968
--                 Line_Item2_47_Style NVARCHAR(20) default '',                   -- #969 Style
--                 Line_Item2_47_Color NVARCHAR(10) default '',                   -- #970 Color
--                 Line_Item2_47_Measurement NVARCHAR(5) default '',              -- #971 Measurement
--                 Line_Item2_47_Size_Description NVARCHAR(5) default '',         -- #972 Size
--                 Line_Item2_47_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #973 PACKDETAIL.Qty
--                 Line_Item2_47_ItemNum NVARCHAR(36) default '',                 -- #974 Sku
--                 Line_Item2_47_RetailSKU NVARCHAR(20) default '',               -- #975 Retail SKU
--                 Line_Item2_47_RetailCompSKU NVARCHAR(30) default '',           -- #976 Retail Component SKU
--                 Line_Item2_47_Reserve01 NVARCHAR(30) default '',               -- #977 ParentSKU
--                 Line_Item2_47_Reserve02 NVARCHAR(30) default '',               -- #978
--                 Line_Item2_47_Reserve03 NVARCHAR(30) default '',               -- #979
--                 Line_Item2_47_Reserve04 NVARCHAR(30) default '',               -- #980
--                 Line_Item2_47_Reserve05 NVARCHAR(30) default '',               -- #981
--                 Line_Item2_48_Style NVARCHAR(20) default '',                   -- #982 Style
--                 Line_Item2_48_Color NVARCHAR(10) default '',                   -- #983 Color
--                 Line_Item2_48_Measurement NVARCHAR(5) default '',              -- #984 Measurement
--                 Line_Item2_48_Size_Description NVARCHAR(5) default '',         -- #985 Size
--                 Line_Item2_48_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #986 PACKDETAIL.Qty
--                 Line_Item2_48_ItemNum NVARCHAR(36) default '',                 -- #987 Sku
--                 Line_Item2_48_RetailSKU NVARCHAR(20) default '',               -- #988 Retail SKU
--                 Line_Item2_48_RetailCompSKU NVARCHAR(30) default '',           -- #989 Retail Component SKU
--                 Line_Item2_48_Reserve01 NVARCHAR(30) default '',               -- #990 ParentSKU
--                 Line_Item2_48_Reserve02 NVARCHAR(30) default '',               -- #991
--                 Line_Item2_48_Reserve03 NVARCHAR(30) default '',               -- #992
--                 Line_Item2_48_Reserve04 NVARCHAR(30) default '',               -- #993
--                 Line_Item2_48_Reserve05 NVARCHAR(30) default '',               -- #994
--                 Line_Item2_49_Style NVARCHAR(20) default '',                   -- #995 Style
--                 Line_Item2_49_Color NVARCHAR(10) default '',                   -- #996 Color
--                 Line_Item2_49_Measurement NVARCHAR(5) default '',              -- #997 Measurement
--                 Line_Item2_49_Size_Description NVARCHAR(5) default '',         -- #998 Size
--                 Line_Item2_49_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #999 PACKDETAIL.Qty
--                 Line_Item2_49_ItemNum NVARCHAR(36) default '',                 -- #1000 Sku
--                 Line_Item2_49_RetailSKU NVARCHAR(20) default '',               -- #1001 Retail SKU
--                 Line_Item2_49_RetailCompSKU NVARCHAR(30) default '',           -- #1002 Retail Component SKU
--                 Line_Item2_49_Reserve01 NVARCHAR(30) default '',               -- #1003 ParentSKU
--                 Line_Item2_49_Reserve02 NVARCHAR(30) default '',               -- #1004
--                 Line_Item2_49_Reserve03 NVARCHAR(30) default '',               -- #1005
--                 Line_Item2_49_Reserve04 NVARCHAR(30) default '',               -- #1006
--                 Line_Item2_49_Reserve05 NVARCHAR(30) default '',               -- #1007
--                 Line_Item2_50_Style NVARCHAR(20) default '',                   -- #1008 Style
--                 Line_Item2_50_Color NVARCHAR(10) default '',                   -- #1009 Color
--                 Line_Item2_50_Measurement NVARCHAR(5) default '',              -- #1010 Measurement
--                 Line_Item2_50_Size_Description NVARCHAR(5) default '',         -- #1011 Size
--                 Line_Item2_50_NoOfUnits_For_Size NVARCHAR(5) default '',       -- #1012 PACKDETAIL.Qty
--                 Line_Item2_50_ItemNum NVARCHAR(36) default '',                 -- #1013 Sku
--                 Line_Item2_50_RetailSKU NVARCHAR(20) default '',               -- #1014 Retail SKU
--                 Line_Item2_50_RetailCompSKU NVARCHAR(30) default '',           -- #1015 Retail Component SKU
--                 Line_Item2_50_Reserve01 NVARCHAR(30) default '',               -- #1016 ParentSKU
--                 Line_Item2_50_Reserve02 NVARCHAR(30) default '',               -- #1017
--                 Line_Item2_50_Reserve03 NVARCHAR(30) default '',               -- #1018
--                 Line_Item2_50_Reserve04 NVARCHAR(30) default '',               -- #1019
--                 Line_Item2_50_Reserve05 NVARCHAR(30) default '',               -- #1020
--                 Primary key (SeqNo)
--               )


/*********************************************/
/* Temp Tables Creation (End)                */
/*********************************************/
 DECLARE @n_RunNumber Int
 SELECT @n_RunNumber = 0
/*********************************************/
/* Data extraction (Start)                   */
/*********************************************/

   IF @b_debug = 1
   BEGIN
      SELECT 'Extract records into Temp table - #TempGSICartonLabel_Rec...'
   END
   -- Extract records into Temp table.

   SELECT  TOP 1
           @c_Facility_Ship_From_Name              = LEFT(ISNULL(RTRIM(STORER.Company),''), 45),
           @c_Facility_Shipping_Address1           = ISNULL(RTRIM(SUBSTRING(FACILITY.Descr,1,25)),''),
           @c_Facility_Shipping_Address2           = ISNULL(RTRIM(SUBSTRING(FACILITY.Descr,26,25)),''),
           @c_Facility_Shipping_City               = LEFT(ISNULL(RTRIM(FACILITY.UserDefine01),''), 25),
           @c_Facility_Shipping_State              = LEFT(ISNULL(RTRIM(FACILITY.UserDefine03),''), 2),
           @c_Facility_Shipping_Zip                = LEFT(ISNULL(RTRIM(FACILITY.UserDefine04),''), 5),
           @c_Storer_Name                          = LEFT(ISNULL(RTRIM(STORER.Company),''), 25),
           @c_Facility_Number                      = LEFT(ISNULL(RTRIM(ORDERS.Facility),''), 3),
           @c_Carrier_Name                         = LEFT(ISNULL(RTRIM(STORERMBOL.Company),''), 30),
           @c_Proof_Of_Delivery                    = '', -- @c_Proof_Of_Delivery
           @c_VICS_BOL                             = LEFT(ISNULL(RTRIM(MBOL.ExternMBOLKey),''), 17),
           @c_Carrier_SCAC_Code                    = LEFT(ISNULL(RTRIM(MBOL.CarrierKey),''), 4),
           @c_Non_VICS_BOL                         = SUBSTRING(ISNULL(RTRIM(@c_MBOLKey),''),5,6),
           @c_Order_Session                        = LEFT(ISNULL(RTRIM(MBOL.BookingReference),''), 30),
           @c_Ship_To_Consignee                    = LEFT(ISNULL(RTRIM(ORDERS.ConsigneeKey),''), 15),
           @c_Ship_To_Consignee_Name               = LEFT(ISNULL(RTRIM(ORDERS.C_Company),''), 45),
           @c_Ship_To_Consignee_Address1           = LEFT(ISNULL(RTRIM(ORDERS.C_Address1),''), 45),
           @c_Ship_To_Consignee_Address2           = LEFT(ISNULL(RTRIM(ORDERS.C_Address2),''), 45),
           @c_Ship_To_Consignee_City               = LEFT(ISNULL(RTRIM(ORDERS.C_City),''), 25),
           @c_Ship_To_Consignee_State              = LEFT(ISNULL(RTRIM(ORDERS.C_State),''), 2),
           @c_Ship_To_Consignee_Zip                = LEFT(ISNULL(RTRIM(ORDERS.C_ZIP),''), 5),
           @c_Ship_To_Consignee_ISOCntryCode       = LEFT(ISNULL(RTRIM(ORDERS.C_ISOCntryCode),''), 10),
           @c_Class_of_Service                     = LEFT(ISNULL(RTRIM(ORDERS.M_Phone2),''), 18),
           @c_Shipper_Account_No                   = LEFT(ISNULL(RTRIM(ORDERS.M_Fax1),''), 18),
           @c_Shipment_No                          = LEFT(ISNULL(RTRIM(ORDERS.M_Fax2),''), 18),
           @c_Final_Destination_Consignee_Name     = CASE LEFT(ISNULL(RTRIM(ORDERS.M_Company),''), 45)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_Company),''), 45)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_Company),''), 45)
                                                     END,
           @c_Final_Destination_Consignee_Address1 = CASE LEFT(ISNULL(RTRIM(ORDERS.M_Address1),''), 45)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_Address1),''), 45)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_Address1),''), 45)
                                                     END,
           @c_Final_Destination_Consignee_Address2 = CASE LEFT(ISNULL(RTRIM(ORDERS.M_Address2),''), 45)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_Address2),''), 45)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_Address2),''), 45)
                                                     END,
           @c_Final_Destination_Consignee_City     = CASE LEFT(ISNULL(RTRIM(ORDERS.M_City),''), 25)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_City),''), 25)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_City),''), 25)
                                                     END,
           @c_Final_Destination_Consignee_State    = CASE LEFT(ISNULL(RTRIM(ORDERS.M_State),''), 2)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_State),''), 2)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_State),''), 2)
                                                     END,
           @c_Final_Destination_Consignee_Zip      = CASE LEFT(ISNULL(RTRIM(ORDERS.M_Zip),''), 18)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_Zip),''), 18)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_Zip),''), 18)
                                                     END,
           @c_Final_Destination_Consignee_Store    = CASE LEFT(ISNULL(RTRIM(ORDERS.MarkForKey),''), 15)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.ConsigneeKey),''), 15) -- AAY0019
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.MarkForKey),''), 15)      -- AAY0019
                                                     END, -- AAY003
           @c_Buying_Store                         = LEFT(ISNULL(RTRIM(ORDERS.BillToKey),''), 15),                -- AAY0019
           @c_Ship_To_Consignee_Zip2               = LEFT(ISNULL(RTRIM(ORDERS.C_Zip),''), 18),                                         -- AAY0023 #2
           @c_Buying_Consignee_Zip                 = '', -- Buying Consignee Zip
           @c_Storer_Vendor_Num                    = LEFT(ISNULL(RTRIM(ORDERS.UserDefine05),''), 10),
           @c_Buying_Consignee_Ship_To_Name        = LEFT(ISNULL(RTRIM(ORDERS.B_Company),''), 45),                -- AAY002-#2
           @c_Buying_Consignee_Ship_To_Address1    = LEFT(ISNULL(RTRIM(ORDERS.B_Address1),''), 45),               -- AAY002-#2
           @c_Buying_Consignee_Ship_To_Address2    = LEFT(ISNULL(RTRIM(ORDERS.B_Address2),''), 45),               -- AAY002-#2
           @c_Buying_Consignee_Ship_To_City      = LEFT(ISNULL(RTRIM(ORDERS.B_City),''), 25),
           @c_Buying_Consignee_Ship_To_State       = LEFT(ISNULL(RTRIM(ORDERS.B_State),''), 2),
           @c_Buying_Consignee_Ship_To_Zip         = LEFT(ISNULL(RTRIM(ORDERS.B_Zip),''), 5),
           @c_Buying_Consignee_Region              = LEFT(ISNULL(RTRIM(ORDERS.B_ISOCntryCode),''), 10),                                -- AAY001-#2
           @c_Purchase_Order_Number                = LEFT(ISNULL(RTRIM(CASE WHEN RIGHT(ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),''), 5) = '-CONS'
                                                               THEN ORDERDETAIL.ExternConsoOrderkey
                                                               ELSE ORDERS.ExternOrderkey
                                                          END),''), 24), --NJOW08
           @c_Department_Number                    = LEFT(ISNULL(RTRIM(ORDERS.UserDefine03),''), 7),
           @c_Department_Name                      = LEFT(ISNULL(RTRIM(ORDERS.M_Contact2),''), 30),                                    --AAY013
           @c_PO_Type                              = LEFT(ISNULL(RTRIM(ORDERS.ExternPOKey),''), 20),
           @c_Dock_Number                          = LEFT(ISNULL(RTRIM(ORDERS.Door),''), 6),
           @c_Product_Group                        = '',
           @c_PickUp_Date                          = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, MBOL.USERDEFINE07))), 2) + '/'    --AAY0021
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, MBOL.USERDEFINE07))), 2) + '/'    --AAY0021
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, MBOL.USERDEFINE07))), 2) + ' '
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(HOUR, MBOL.USERDEFINE07))), 2) + ':'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MINUTE, MBOL.USERDEFINE07))), 2),      --AAY0021
           @c_Order_Product_Group                  = LEFT(ISNULL(RTRIM(ORDERS.LabelPrice),''), 5),                                     --AAY0022
           @c_Duplicate_Label_Message              = LEFT(ISNULL(RTRIM(ORDERS.Userdefine01),''), 20),                                  --AAYXXX - Load ID
           @c_Julian_Day                           = CASE ISNULL(RTRIM(MBOL.USERDEFINE07),'')                                          --AAY0023 #5
                                                        WHEN '' THEN RIGHT(DBO.TO_JULIAN(GETDATE()),3)
                                                        ELSE RIGHT(DBO.TO_JULIAN(MBOL.USERDEFINE07),3)
                                                     END,                                                                              -- AAY0023 #5
           @c_Order_Start_Date                     = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, ORDERS.OrderDate))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, ORDERS.OrderDate))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, ORDERS.OrderDate))), 2),
           @c_Order_Completion_Date                = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, ORDERS.DeliveryDate))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, ORDERS.DeliveryDate))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, ORDERS.DeliveryDate))), 2),
           @c_Pick_Ticket_Number                   = LEFT(ISNULL(RTRIM(CASE WHEN RIGHT(ISNULL(RTRIM(ORDERDETAIL.ExternConsoOrderkey),''),5) = '-CONS'
                                                               THEN ORDERDETAIL.ConsoOrderkey
                                                               ELSE ORDERS.BuyerPO
                                                          END),''), 20),
                                                   -- LEFT(ISNULL(RTRIM(ORDERS.BuyerPO),''), 20),  -- AAY001-#3
           @c_File_Create_Date                     = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, GETDATE()))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, GETDATE()))), 2) + '/'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, GETDATE()))), 2),               -- @c_Date
           @c_File_Create_Time                     = RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(HOUR, GETDATE()))), 2) + ':'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MINUTE, GETDATE()))), 2) + ':'
                                                     + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(SECOND, GETDATE()))), 2),             -- @c_Time
           @c_Consignee_Account_Number             = LEFT(ISNULL(RTRIM(ORDERS.StorerKey),''), 8),                                      -- AAY004-#1
           @c_Blank03                              = LEFT(ISNULL(RTRIM(ORDERS.C_Phone1),''), 18),
           @c_Blank04                              = LEFT(ISNULL(RTRIM(ORDERS.C_Contact1),''), 30),
           @c_Blank05                              = LEFT(ISNULL(RTRIM(ORDERS.C_Country),''), 30),
           @c_Blank12                              = LEFT(ISNULL(RTRIM(ORDERS.B_Contact2),''), 30),
           @c_Blank22                              = LEFT(ISNULL(RTRIM(ORDERS.C_Fax2),''), 18),
           @c_Blank23                              = LEFT(ISNULL(RTRIM(ORDERS.C_Fax1),''), 18),
           @c_Bin_Location                         = LEFT(ISNULL(RTRIM(ORDERS.Salesman),''), 30),
           @c_Total_number_of_cartons              = LEFT(ISNULL(RTRIM(ORDERS.PMTTerm),''), 10),
           @c_Reserve01                            = CASE LEFT(ISNULL(RTRIM(ORDERS.M_Address3),''), 45)
                                                        WHEN '' THEN LEFT(ISNULL(RTRIM(ORDERS.C_Address3),''), 45)
                                                        ELSE LEFT(ISNULL(RTRIM(ORDERS.M_Address3),''), 45)
                                                     END,                                                    --MC02
           @c_Reserve02                            = LEFT(ISNULL(RTRIM(ORDERS.B_Address3),''), 45),          --MC02
           @c_Reserve03                            = LEFT(ISNULL(RTRIM(ORDERS.C_Address3),''), 45),          --MC02
           @c_MisclFlag                            = ISNULL(RTRIM(ORDERS.B_FAX1),'')    -- #367
   FROM ORDERS ORDERS WITH (NOLOCK)
   JOIN ORDERDETAIL ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey AND               --MC01 - Since not match to OD, remove it --NJOW08
                                                   ORDERS.StorerKey = ORDERDETAIL.StorerKey )               --MC01 - Since not match to OD, remove it --NJOW08
   JOIN FACILITY FACILITY WITH (NOLOCK) ON ( ORDERS.Facility = FACILITY.Facility )
   JOIN STORER STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )
   LEFT JOIN MBOLDETAIL MBOLDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = MBOLDETAIL.OrderKey )   --NJOW02
   LEFT JOIN MBOL MBOL WITH (NOLOCK) ON ( MBOLDETAIL.MBOLKey = MBOL.MBOLKey )                   --NJOW02
   LEFT OUTER JOIN STORER STORERMBOL WITH (NOLOCK) ON ( STORERMBOL.StorerKey = MBOL.CarrierKey )
   WHERE ORDERS.OrderKey = @c_OrderKey

   SELECT @c_RCCGroup  = ISNULL(RTRIM(OrderInfo06),'')
   FROM   OrderInfo WITH (NOLOCK)
   WHERE  OrderKey = @c_OrderKey

  DECLARE @c_UCC           NVARCHAR(20)
         , @n_UCCLen        Int
         , @c_PackagingType NVARCHAR(1)
         , @c_SerialSCCwCD  NVARCHAR(20)
         , @c_SerialSCCwoCD NVARCHAR(20)
         , @c_SerialSCCkey NVARCHAR(10)
         , @n_length        Int
         , @n_Cnt           Int
         , @n_Odd           Int
         , @n_Even          Int
         , @n_CheckDigit    Int

   SET @b_success       = 0
   SET @c_PackagingType = ''

   -- GET UCC & Packaging Type
   SELECT @c_UCC = MAX(STORER.SUSR1)
     FROM STORER WITH (NOLOCK)
    WHERE STORER.StorerKey = @c_StorerKey

   IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
   BEGIN
      SELECT DISTINCT @c_PackagingType = CASE WHEN MAX(PACK.PackKey) = 'GOH' THEN 1 ELSE 0 END
      FROM PACK WITH (NOLOCK)
        JOIN SKU WITH (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
        JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey)
       WHERE OrderKey = @c_OrderKey
         AND ConsoOrderKey = @c_ConsoOrderKey
   END   --(MC01) - E
   ELSE
   BEGIN
      SELECT DISTINCT @c_PackagingType = CASE WHEN MAX(PACK.PackKey) = 'GOH' THEN 1 ELSE 0 END
        FROM PACK WITH (NOLOCK)
        JOIN SKU WITH (NOLOCK) ON (PACK.PackKey = SKU.PackKey)
        JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey)
       WHERE OrderKey = @c_OrderKey
   END


-- CheckPoint
    -- Assign SSCC18 to variable
    --SELECT @c_LabelNo = Serial_SCC_With_Check_Digit                                          -- LAu0003
    --FROM #TempGSICartonLabel_Rec (nolock)                                                    -- LAu0003

   /*********************************************/
   /* Cursor Loop - Record Level (Start)        */
   /*********************************************/

   SET @c_BuyerPO = ''

   -- Validate if this is calling from Packing Module
   IF ISNULL(RTRIM(@n_CartonNoParm),0) <> 0
   BEGIN

--      DECLARE GSI_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--       SELECT SeqNo, SeqLineNo, Non_VICS_BOL, Consignee_Account_Number,
--              Pick_Ticket_Number, Purchase_Order_Number, Sequential_Carton_Number
--         FROM #TempGSICartonLabel_Rec
--        WHERE Sequential_Carton_Number = @n_CartonNoParm

      DECLARE GSI_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT LEFT(ISNULL(RTRIM(PACKREC.CartonType),''), 8),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.TotQty)),0), 5),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.CartonNo)),0), 5),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.TotCarton)),0), 4),
              LEFT(ISNULL(RTRIM(PACKREC.UPC),''), 20),
              LEFT(ISNULL(RTRIM(PACKREC.LabelNo),''), 19),
              LEFT(ISNULL(RTRIM(PACKREC.LabelNo),''), 20),
              ISNULL(RIGHT(RTRIM(CONVERT(Char, PACKREC.TTLCnts)), 6),'0'),  -- Total_Cartons_In_Shipment  SHONG01
              ISNULL(LEFT(LTRIM(CONVERT(Char, PACKREC.TotCtnWeight)), 5),'0'),
              LEFT(ISNULL(RTRIM(PACKREC.ContentDesc),''), 30),
              LEFT(ISNULL(RTRIM(PACKREC.RouteCode),''), 20),
              LEFT(ISNULL(RTRIM(PACKREC.Address),''), 25),
              LEFT(ISNULL(RTRIM(PACKREC.City),''), 25),
              LEFT(ISNULL(RTRIM(PACKREC.State),''), 10),
              LEFT(ISNULL(RTRIM(PACKREC.ZIP),''), 10),
              LEFT(ISNULL(RTRIM(PACKREC.Refno2),''), 30),
              LEFT(ISNULL(RTRIM(CSD.FormCode),''),10),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.RoutingCode),''),10),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.ASTRA_Barcode),''),45),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.TrackingNumber),''),15),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.PlannedServiceLevel),''),30),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.ServiceTypeDescription),''),45),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.SpecialHandlingIndicators),''),30),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.DestinationAirportID),''),5),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.GroundBarcodeString),''),30)  --NJOW09
       FROM #Pack_Det PACKREC
       LEFT JOIN CARTONSHIPMENTDETAIL CSD WITH (NOLOCK)
               ON (PACKREC.Labelno = CSD.UCCLabelNo)
       WHERE CartonNo = @n_CartonNoParm

   END -- IF ISNULL(RTRIM(@n_CartonNoParm),0) <> 0
   ELSE
   BEGIN

--      DECLARE GSI_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--       SELECT SeqNo, SeqLineNo, Non_VICS_BOL, Consignee_Account_Number,
--              Pick_Ticket_Number, Purchase_Order_Number, Sequential_Carton_Number
--         FROM #TempGSICartonLabel_Rec


      DECLARE GSI_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT LEFT(ISNULL(RTRIM(PACKREC.CartonType),''), 8),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.TotQty)),0), 5),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.CartonNo)),0), 5),
              RIGHT(ISNULL(RTRIM(CONVERT(Char, PACKREC.TotCarton)),0), 4),
              LEFT(ISNULL(RTRIM(PACKREC.UPC),''), 20),
              LEFT(ISNULL(RTRIM(PACKREC.LabelNo),''), 19),
              LEFT(ISNULL(RTRIM(PACKREC.LabelNo),''), 20),
              ISNULL(RIGHT(RTRIM(CONVERT(Char, PACKREC.TTLCnts)), 6),'0'),  -- Total_Cartons_In_Shipment  SHONG01
              ISNULL(LEFT(LTRIM(CONVERT(Char, PACKREC.TotCtnWeight)), 5),'0'),
              LEFT(ISNULL(RTRIM(PACKREC.ContentDesc),''), 30),
              LEFT(ISNULL(RTRIM(PACKREC.RouteCode),''), 20),
              LEFT(ISNULL(RTRIM(PACKREC.Address),''), 25),
              LEFT(ISNULL(RTRIM(PACKREC.City),''), 25),
              LEFT(ISNULL(RTRIM(PACKREC.State),''), 10),
            LEFT(ISNULL(RTRIM(PACKREC.ZIP),''), 10),
              LEFT(ISNULL(RTRIM(PACKREC.Refno2),''), 30),
              LEFT(ISNULL(RTRIM(CSD.FormCode),''),10),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.RoutingCode),''),10),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.ASTRA_Barcode),''),45),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.TrackingNumber),''),15),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.PlannedServiceLevel),''),30),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.ServiceTypeDescription),''),45),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.SpecialHandlingIndicators),''),30),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.DestinationAirportID),''),5),  --NJOW09
              LEFT(ISNULL(RTRIM(CSD.GroundBarcodeString),''),30)  --NJOW09
       FROM #Pack_Det PACKREC
       LEFT JOIN CARTONSHIPMENTDETAIL CSD WITH (NOLOCK)
               ON (PACKREC.Labelno = CSD.UCCLabelNo)

   END -- IF ISNULL(RTRIM(@n_CartonNoParm),'') = ''

   OPEN GSI_Rec_Cur

--   FETCH NEXT FROM GSI_Rec_Cur INTO @n_SeqNo, @n_SeqLineNo, @c_MBOLKey, @c_StorerKey,
--                                    @c_BuyerPO, @c_ExternOrderKey, @c_CartonNo


   FETCH NEXT FROM GSI_Rec_Cur INTO
            @c_Case_Type,
            @c_Total_Units_This_Carton,
            @c_Sequential_Carton_Number,
            @c_Total_Cartons_Per_Store,
            @c_CartonTrackingNo,
            @c_Serial_SCC_Without_Check_Digit,
            @c_Serial_SCC_With_Check_Digit,
            @c_Total_Cartons_In_Shipment,
            @c_Carton_Weight,
            @c_Blank02,
            @c_Blank17,
            @c_Blank18,
            @c_Blank19,
            @c_Blank20,
            @c_Blank21,
            @c_Pick_Ticket_Suffix,
            @c_Reserve04,
            @c_Reserve05,
            @c_Reserve06,
            @c_Reserve07,
            @c_Reserve09,
            @c_Reserve10,
            @c_Reserve11,
            @c_Reserve12,
            @c_Reserve13



   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      /*********************************************/
      /* Serial SCC Generation (Start)             */
      /*********************************************/
      SET @c_UCC           = ''
      SET @n_UCCLen        = 0

      SET @c_SerialSCCwCD  = ''
      SET @c_SerialSCCwoCD = ''
      SET @c_SerialSCCkey  = ''
      SET @n_length        = 0
      SET @n_Cnt           = 0
      SET @n_Odd           = 0
      SET @n_Even          = 0
      SET @n_CheckDigit    = 0

      SET @c_LabelNo = @c_Serial_SCC_With_Check_Digit
      SET @c_CartonNo = @c_Sequential_Carton_Number

      IF @b_debug = 2
      BEGIN
         SELECT '@c_UCC/@c_PackagingType: ', @c_UCC + '/' + @c_PackagingType
      END

      -- IF UCC not present

      IF (ISNULL(RTRIM(@c_UCC),'') = '') OR (LEN(RTRIM(@c_UCC)) = 0)
      BEGIN
         SET @c_UCC = '0400000'
      END
      ELSE
      BEGIN
         IF LEN(RTRIM(@c_UCC)) < 7
            SET @c_UCC = RIGHT(RTRIM(REPLICATE('0', 7) + ISNULL(CAST(@c_UCC AS NVARCHAR(7)), '0')),7)
      END

      IF ISNUMERIC(@c_UCC) = 0  -- Not Numeric
         SET @c_UCC = '0400000'

      -- Get Serial key for label
      SET @b_success = 1

      EXECUTE nspg_getkey
             'SerialSCC'
            , 9
            , @c_SerialSCCkey OUTPUT
            , @b_success      OUTPUT
            , @n_err          OUTPUT
            , @c_errmsg       OUTPUT

      WHILE @@TRANCOUNT > 0
         COMMIT TRAN

      SET @c_SerialSCCkey = RIGHT(RTRIM(REPLICATE('0', 9) + ISNULL(CAST(@c_SerialSCCkey AS NVARCHAR(9)), '0')),9)

      -- Set Serial SCC Code in full without Check Digit
      SET @c_SerialSCCwoCD = '00' + ISNULL(RTRIM(@c_PackagingType),'') + ISNULL(RTRIM(@c_UCC),'') +
                              ISNULL(RTRIM(@c_SerialSCCkey),'')

      IF @b_debug = 2
      BEGIN
         SELECT '@c_SerialSCCwoCD: ', @c_SerialSCCwoCD
      END

      SET @n_length = LEN(@c_SerialSCCwoCD)

      IF (@n_length > 0)
      BEGIN
         SET @n_Cnt = 1

         WHILE @n_Cnt <= @n_length
         BEGIN
            IF (@n_Cnt % 2) > 0
            BEGIN
               -- Add all digit in Odd Placement
               SET @n_Odd = ISNULL(RTRIM(@n_Odd),0) +
                            CAST(SUBSTRING(ISNULL(RTRIM(@c_SerialSCCwoCD),''),
                                      CAST(ISNULL(RTRIM(@n_Cnt),0) AS Int), 1) AS Int)
            END
            ELSE
            BEGIN
               -- Add all digit in Even Placement
               SET @n_Even = ISNULL(RTRIM(@n_Even),0) +
                             CAST(SUBSTRING(ISNULL(RTRIM(@c_SerialSCCwoCD),''),
                             CAST(ISNULL(RTRIM(@n_Cnt),0) AS Int), 1) AS Int)
            END

            SET @n_Cnt = ISNULL(RTRIM(@n_Cnt),0) + 1
            CONTINUE
         END
      END

  -- @n_Even - Hardcod Multiply by 3
      -- Modulo function get last digit of added result
      -- Check digit is 10 - @n_Cnt

      SET @n_CheckDigit = 10 - ((ISNULL(RTRIM(@n_Odd),0) + (ISNULL(RTRIM(@n_Even),0) * 3)) % 10)

      IF (@n_CheckDigit = 10)
      BEGIN
         SET @n_CheckDigit = 0
      END

      -- Set Serial SCC Code in full with Check Digit
      SET @c_SerialSCCwCD = ISNULL(RTRIM(@c_SerialSCCwoCD),'') + CONVERT(Char(1), ISNULL(RTRIM(@n_CheckDigit),0))

      IF @b_debug = 2
      BEGIN
          SELECT 'Serial_SCC_Without_Check_Digit/Serial_SCC_With_Check_Digit: ',
                  @c_SerialSCCwoCD + '/' + @c_SerialSCCwCD
      END

      /*********************************************/
      /* Serial SCC Generation (End)               */
      /*********************************************/
      /* Other info capturing (Start)              */
      /*********************************************/

      SET @n_TotQty    = 0
      SET @n_TotSkuQty = 0
      SET @c_SingleSku = ''
      SET @c_SkuDescr  = ''
      SET @c_RetailSku = ''
      SET @n_CtnByMbol = @n_CtnByMbol + 1
      SET @c_PkInCnt   = '' --LAu002
      SET @c_PkSzScl   = '' --AAY008
      SET @c_PkQtyScl  = '' --AAY008
      SET @c_PkDesc    = '' --AAY009
      SET @c_MstrSKU   = '' --AAY011
      SET @c_SKUDept   = '' --AAY0014
      SET @c_SKUProd   = '' --AAY0014
      SET @c_PrintedBy = '' --AAY0015

      IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
      BEGIN
         SELECT @c_PkInCnt = ORDERDETAIL.USERDEFINE09,
                @c_PkSzScl = ORDERDETAIL.USERDEFINE06, --AAY008
                @c_PkQtyScl = ORDERDETAIL.USERDEFINE07, --AAY008
                @c_PkDesc = ORDERDETAIL.USERDEFINE08, -- AAY008
                @c_MstrSKU = ORDERDETAIL.ManufacturerSKU, --AAY011
                @c_SKUDept = ORDERDETAIL.USERDEFINE01,  --AAY014
                @c_SKUProd = ORDERDETAIL.USERDEFINE02  --AAY014
         FROM ORDERDETAIL WITH (NOLOCK)
         JOIN PACKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.SKU = PACKDETAIL.SKU)
         JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
                                           AND PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
         WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
         AND PACKDETAIL.CartonNo = @c_CartonNo
         AND PACKHEADER.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey -- (ChewKP03)
         AND ORDERDETAIL.ORDERKEY = @c_OrderKey
         AND LEN(RTRIM(ORDERDETAIL.USERDEFINE09))>0
         AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
      END   --(MC01) - E
      ELSE
      BEGIN
         --AAY007 Start
         SELECT
            @c_PkInCnt = ORDERDETAIL.USERDEFINE09,
            @c_PkSzScl = ORDERDETAIL.USERDEFINE06, --AAY008
            @c_PkQtyScl = ORDERDETAIL.USERDEFINE07, --AAY008
            @c_PkDesc = ORDERDETAIL.USERDEFINE08, -- AAY008
            @c_MstrSKU = ORDERDETAIL.ManufacturerSKU, --AAY011
            @c_SKUDept = ORDERDETAIL.USERDEFINE01,  --AAY014
            @c_SKUProd = ORDERDETAIL.USERDEFINE02  --AAY014
         FROM ORDERDETAIL WITH (NOLOCK)
         JOIN PACKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.SKU = PACKDETAIL.SKU)
         JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo
                                         AND  PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
         WHERE PACKHEADER.ORDERKEY = @c_OrderKey
         AND PACKDETAIL.CartonNo = @c_CartonNo
         AND PACKHEADER.ORDERKEY = ORDERDETAIL.ORDERKEY
         AND LEN(RTRIM(ORDERDETAIL.USERDEFINE09))>0
         AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         --AAY007 End
      END

      SELECT @c_PrintedBy = suser_name()  --AAY015

      IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
      BEGIN
--         SELECT @n_SkuCnt = COUNT(PACKDETAIL.Sku)
--           FROM PACKDETAIL WITH (NOLOCK)
--           JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
--                                             PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
--          WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
--            AND PACKDETAIL.CartonNo = @c_CartonNo
--            AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
--         HAVING COUNT(PACKDETAIL.Sku) = 1
         IF ISNULL(RTRIM(@c_LabelNoParm),'') = ''  -- tlting03
         BEGIN
            SELECT @n_SkuCnt = COUNT(PACKDETAIL.Sku)
              FROM PACKDETAIL WITH (NOLOCK)
              JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                                PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
             WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
               AND PACKDETAIL.CartonNo = @c_CartonNo
            HAVING COUNT(PACKDETAIL.Sku) = 1
         END
         ELSE
         BEGIN
            SELECT @n_SkuCnt = COUNT(PACKDETAIL.Sku)
              FROM PACKDETAIL WITH (NOLOCK)
              JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                                PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
             WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
               AND PACKDETAIL.CartonNo = @c_CartonNo
               AND PACKDETAIL.LabelNo = @c_LabelNoParm            -- tlting03
               --( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
            HAVING COUNT(PACKDETAIL.Sku) = 1
         END
      END   --(MC01) - E
      ELSE
      BEGIN
         SELECT @n_SkuCnt = COUNT(PACKDETAIL.Sku)
           FROM PACKDETAIL WITH (NOLOCK)
           JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                             PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
           WHERE PACKHEADER.OrderKey = @c_OrderKey
            AND PACKDETAIL.CartonNo = @c_CartonNo
         AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         HAVING COUNT(PACKDETAIL.Sku) = 1
      END

      IF @n_SkuCnt = 1 -- If single sku in carton
      BEGIN
         IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> ''
         BEGIN
            SELECT @n_TotSkuQty = ISNULL(RTRIM(PACKDET.Qty),0),
                   @c_SingleSku = ISNULL(RTRIM(ORDERDETAIL.Sku),''),
                   @c_SkuDescr = LEFT(ISNULL(RTRIM(SKU.BUSR1),''), 30),
                   @c_RetailSku = ISNULL(RTRIM(ORDERDETAIL.RetailSku),'')
            FROM   ORDERDETAIL WITH (NOLOCK)
            JOIN   SKU WITH (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey)
            JOIN   (SELECT PACKHEADER.StorerKey, Sku, CartonNo, SUM(Qty) AS Qty
                    FROM   PACKDETAIL WITH (NOLOCK)
                    JOIN   PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                                        PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
                    WHERE  PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
                    AND    PACKDETAIL.CartonNo = @c_CartonNo
                    AND (  PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04 (add by Larry)
                    GROUP BY PACKHEADER.StorerKey, Sku, CartonNo ) AS PACKDET
            ON     (PACKDET.StorerKey = ORDERDETAIL.StorerKey AND PACKDET.Sku = ORDERDETAIL.Sku)
            WHERE  ORDERDETAIL.ORDERKEY = @c_OrderKey
              AND  ORDERDETAIL.ConsoOrderKey = @c_ConsoOrderKey
            GROUP BY PACKDET.Qty, ORDERDETAIL.Sku, SKU.BUSR1, ORDERDETAIL.RetailSku             -- AAY005
         END   --(MC01) - E
         ELSE
         BEGIN
            SELECT @n_TotSkuQty = ISNULL(RTRIM(PACKDET.Qty),0),
                   @c_SingleSku = ISNULL(RTRIM(ORDERDETAIL.Sku),''),
                   @c_SkuDescr = LEFT(ISNULL(RTRIM(SKU.BUSR1),''), 30),        -- RY20090601
                   @c_RetailSku = ISNULL(RTRIM(ORDERDETAIL.RetailSku),'')
            FROM   ORDERDETAIL WITH (NOLOCK)
            JOIN   SKU WITH (NOLOCK) ON (ORDERDETAIL.Sku = SKU.Sku AND ORDERDETAIL.StorerKey = SKU.StorerKey)
            JOIN   (SELECT PACKHEADER.StorerKey, Sku, CartonNo, SUM(Qty) AS Qty
                    FROM   PACKDETAIL WITH (NOLOCK)
                    JOIN   PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                                      PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
                    WHERE  PACKHEADER.OrderKey = @c_OrderKey
                    AND    PACKDETAIL.CartonNo = @c_CartonNo
                    AND (  PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04 (add by Larry)
                    GROUP BY PACKHEADER.StorerKey, Sku, CartonNo ) AS PACKDET
            ON     (PACKDET.StorerKey = ORDERDETAIL.StorerKey AND PACKDET.Sku = ORDERDETAIL.Sku)
            WHERE  ORDERDETAIL.OrderKey = @c_OrderKey                                           -- SHONG20090310 * Added By SHONG on 10th Mar 2009
            GROUP BY PACKDET.Qty, ORDERDETAIL.Sku, SKU.BUSR1, ORDERDETAIL.RetailSku             -- AAY005
         END
      END -- IF @n_SkuCnt = 1 -- If single sku in carton
      ELSE
      BEGIN
         SET @n_TotSkuQty = ''
         SET @c_SingleSku = ''
         SET @c_SkuDescr = ''
         SET @c_RetailSku = ''
      END

      -- Update related fields
--      UPDATE #TempGSICartonLabel_Rec WITH (ROWLOCK)
--         SET Total_Units_This_Carton_2 = @n_TotSkuQty,
--             GTIN_Code                 = @c_SingleSku,
--             Style_Description         = @c_SkuDescr,
--             Consignee_Item            = @c_RetailSku,
--             PackType                  = @c_PkInCnt, --LAu002
--             Pack_Scale                = @c_PkSzScl, --AAY008
--             Pack_Qty                  = @c_PkQtyScl,--AAY008
--             Pack_Desc                 = @c_PkDesc,  --AAY008
--             MasterSKU                 = @c_MstrSKU, --AAY011
--             SKUDept                   = @c_SKUDept, --AAY014
--             SKUProd                   = @c_SKUProd, --AAY014
--             PrintedBy                 = @c_PrintedBy--AAY015
--       WHERE SeqNo     = @n_SeqNo
--         AND SeqLineNo = @n_SeqLineNo

         SET @c_Total_Units_This_Carton_2 = @n_TotSkuQty
         SET @c_GTIN_Code                 = ISNULL(RTRIM(@c_SingleSku),'')
         SET @c_Style_Description         = ISNULL(RTRIM(@c_SkuDescr),'')
         SET @c_Consignee_Item            = ISNULL(RTRIM(@c_RetailSku),'')
         SET @c_PackType                  = ISNULL(RTRIM(@c_PkInCnt),'')
         SET @c_Pack_Scale                = ISNULL(RTRIM(@c_PkSzScl),'')
--         SET @c_Pack_Qty               = @c_PkQtyScl
         SET @c_PP_Pack_Qty               = ISNULL(RTRIM(@c_PkQtyScl),'') ----AAY20120217
         SET @c_Pack_Desc                 = ISNULL(RTRIM(@c_PkDesc),'')
         SET @c_MasterSKU                 = ISNULL(RTRIM(@c_MstrSKU),'')
         SET @c_SKUDept                   = ISNULL(RTRIM(@c_SKUDept),'')
         SET @c_SKUProd                   = ISNULL(RTRIM(@c_SKUProd),'')
         SET @c_PrintedBy                 = @c_PrintedBy



      /*********************************************/
      /* Other info capturing (End)                */
      /*********************************************/

      /*********************************************/
      /* Cursor Loop - Sku info extraction (Start) */
      /*********************************************/

      SET @n_licnt       = 0
      SET @n_PageNumber  = 0
      SET @n_PageNumber  = @n_PageNumber + 1
      SET @c_Style       = ''
      SET @c_Color       = ''
      SET @c_Measurement = ''
      SET @c_Size        = ''
      SET @c_Pack_Qty    = ''
      SET @c_Sku         = ''
      SET @c_RSku        = ''  --AAY0020
      SET @c_ParentSku   = '' --NJOW10
      SET @c_PrevParentSku = '' --NJOW10

      --NJOW05
      SET @c_CompStyle   = ''
      SET @c_CompColor   = ''
      SET @c_CompMeasurement = ''
      SET @c_CompSize = ''
      SET @n_TotalCartonQty = 0
      SET @c_Pack_Qty = '' --AAY20120217

      --NJOW05
      EXECUTE nspGetRight
      @c_facility,  -- facility
      @c_storerkey,      -- Storerkey
      NULL,      -- Sku
      'APPLY_ORDERDETAILREF', -- Configkey
      @b_success       OUTPUT,
      @c_Apply_OrderDetailRef OUTPUT,
      @n_err           OUTPUT,
      @c_errmsg        OUTPUT

      IF @b_debug = 1
      BEGIN
         SELECT 'CSI_Sku_Cur.. '
         SELECT SKU.Style, SKU.Color, SKU.Measurement, SKU.[Size],
                PACKDETAIL.Qty, SKU.Sku, ORDERDETAIL.RetailSKU --AAY0020
           FROM SKU WITH (NOLOCK)
           JOIN PACKDETAIL WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.Sku = PACKDETAIL.Sku)
           JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                             PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
           --AAY0020 START
           JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ORDERKEY=ORDERDETAIL.ORDERKEY AND
                                               PACKDETAIL.SKU=ORDERDETAIL.SKU)
           --AAY0020 END
          WHERE PACKHEADER.OrderKey = @c_OrderKey
            AND PACKDETAIL.CartonNo = @c_CartonNo
            AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04 (add by Laary)
      END

      IF @c_Apply_OrderDetailRef = '1' --NJOW05
      BEGIN
         IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
         BEGIN
            DECLARE GSI_Sku_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT DISTINCT
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Sku ELSE SKU.Sku END,                    --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Style ELSE SKU.Style END,                --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Color ELSE SKU.Color END,                --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Measurement ELSE SKU.Measurement END,    --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Size ELSE SKU.Size END,                   --NJOW10
                    PACKDETAIL.Qty,
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN ODREF.ComponentSKU ELSE SKU.Sku END,             --NJOW05
                    ORDERDETAIL.RetailSKU,                                                                              --SOS# 193703
                    ISNULL(ODREF.RetailSKU,'') AS RetailComponentSKU, ISNULL(ODREF.BOMQty,0) AS RetailComponentQty,      --NJOW05/10
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Style ELSE SKU.Style END,                --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Color ELSE SKU.Color END,                --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Measurement ELSE SKU.Measurement END,    --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Size ELSE SKU.Size END                   --NJOW05
               FROM SKU WITH (NOLOCK)
               JOIN PACKDETAIL WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.Sku = PACKDETAIL.Sku)
               JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey AND PACKDETAIL.SKU = ORDERDETAIL.SKU AND PACKDETAIL.StorerKey = ORDERDETAIL.StorerKey) -- (ChewKP03)
               LEFT JOIN ORDERDETAILREF ODREF (NOLOCK) ON (ORDERDETAIL.Orderkey = ODREF.Orderkey AND ORDERDETAIL.OrderLineNumber = ODREF.OrderLineNumber)
               --LEFT JOIN BILLOFMATERIAL BM (NOLOCK) ON (ODREF.ParentSKU = BM.Sku AND ODREF.ComponentSKU = BM.ComponentSKU AND ODREF.Storerkey = BM.Storerkey) --NJOW10
               LEFT JOIN SKU SKUCOMP (NOLOCK) ON (ODREF.Storerkey = SKUCOMP.Storerkey AND ODREF.ComponentSku = SKUCOMP.Sku)
               LEFT JOIN SKU SKUPARENT (NOLOCK) ON (ODREF.Storerkey = SKUPARENT.Storerkey AND ODREF.ParentSku = SKUPARENT.Sku) --NJOW10
              WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
                AND PACKDETAIL.CartonNo = @c_CartonNo
                AND (PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
              ORDER BY 1, 7 --NJOW10
         END    --(MC01) - E
         ELSE
         BEGIN
            DECLARE GSI_Sku_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT DISTINCT
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Sku ELSE SKU.Sku END,                    --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Style ELSE SKU.Style END,                --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Color ELSE SKU.Color END,                --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Measurement ELSE SKU.Measurement END,    --NJOW10
                    CASE WHEN ISNULL(ODREF.ParentSKU,'') <> '' THEN SKUPARENT.Size ELSE SKU.Size END,                   --NJOW10
                    PACKDETAIL.Qty,
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN ODREF.ComponentSKU ELSE SKU.Sku END,             --NJOW05
                    ORDERDETAIL.RetailSKU, --SOS# 193703
                    ISNULL(ODREF.RetailSKU,'') AS RetailComponentSKU, ISNULL(ODREF.BOMQty,0) AS RetailComponentQty,     --NJOW05/10
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Style ELSE SKU.Style END,                --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Color ELSE SKU.Color END,                --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Measurement ELSE SKU.Measurement END,    --NJOW05
                    CASE WHEN ISNULL(ODREF.ComponentSKU,'') <> '' THEN SKUCOMP.Size ELSE SKU.Size END                   --NJOW05
               FROM SKU WITH (NOLOCK)
               JOIN PACKDETAIL WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.Sku = PACKDETAIL.Sku)
               JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
               --AAY0020 START
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ORDERKEY = ORDERDETAIL.ORDERKEY AND PACKDETAIL.SKU=ORDERDETAIL.SKU)
               --AAY0020 END
               --NJOW05
               LEFT JOIN ORDERDETAILREF ODREF (NOLOCK) ON (ORDERDETAIL.Orderkey = ODREF.Orderkey AND ORDERDETAIL.OrderLineNumber = ODREF.OrderLineNumber)
               --LEFT JOIN BILLOFMATERIAL BM (NOLOCK) ON (ODREF.ParentSKU = BM.Sku AND ODREF.ComponentSKU = BM.ComponentSKU AND ODREF.Storerkey = BM.Storerkey)   --NJOW10
               LEFT JOIN SKU SKUCOMP (NOLOCK) ON (ODREF.Storerkey = SKUCOMP.Storerkey AND ODREF.ComponentSku = SKUCOMP.Sku)
               LEFT JOIN SKU SKUPARENT (NOLOCK) ON (ODREF.Storerkey = SKUPARENT.Storerkey AND ODREF.ParentSku = SKUPARENT.Sku) --NJOW10
              WHERE PACKHEADER.OrderKey = @c_OrderKey
                AND PACKDETAIL.CartonNo = @c_CartonNo
                AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
              ORDER BY 1, 7 --NJOW10
         END
      END  --IF @c_Apply_OrderDetailRef = '1' --NJOW05
      ELSE --IF @c_Apply_OrderDetailRef <> '1' --NJOW05
      BEGIN
         IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> '' --(MC01) - S
         BEGIN
            DECLARE GSI_Sku_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT DISTINCT '' AS ParentSku, SKU.Style, SKU.Color, SKU.Measurement, SKU.[Size], PACKDETAIL.Qty,      --NJOW10
                    SKU.Sku,
                    ORDERDETAIL.RetailSKU, --SOS# 193703
                    '' AS RetailComponentSKU,
                    0 AS RetailComponentQty,
                    SKU.Style,
                    SKU.Color,
                    SKU.Measurement,
                    SKU.Size
               FROM SKU WITH (NOLOCK)
               JOIN PACKDETAIL WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.Sku = PACKDETAIL.Sku)
               JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey AND PACKDETAIL.SKU = ORDERDETAIL.SKU AND PACKDETAIL.Storerkey = ORDERDETAIL.Storerkey) -- (ChewKP03)
              WHERE PACKHEADER.ConsoOrderKey = @c_ConsoOrderKey -- (ChewKP03)
                AND PACKDETAIL.CartonNo = @c_CartonNo
                AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  )
         END --(MC01) - E
         ELSE
         BEGIN
            DECLARE GSI_Sku_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
             SELECT DISTINCT '' AS ParentSku, SKU.Style, SKU.Color, SKU.Measurement, SKU.[Size], PACKDETAIL.Qty,         --NJOW10
                    SKU.Sku,
                    ORDERDETAIL.RetailSKU, --SOS# 193703
                    '' AS RetailComponentSKU,
                    0 AS RetailComponentQty,
                    SKU.Style,
                    SKU.Color,
                    SKU.Measurement,
                    SKU.Size
               FROM SKU WITH (NOLOCK)
               JOIN PACKDETAIL WITH (NOLOCK) ON (SKU.StorerKey = PACKDETAIL.StorerKey AND SKU.Sku = PACKDETAIL.Sku)
               JOIN PACKHEADER WITH (NOLOCK) ON (PACKDETAIL.PickSlipNo = PACKHEADER.PickSlipNo AND
                                                 PACKDETAIL.StorerKey = PACKHEADER.StorerKey)
               --AAY0020 START
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ORDERKEY=ORDERDETAIL.ORDERKEY AND
                                                     PACKDETAIL.SKU=ORDERDETAIL.SKU)
               --AAY0020 END
              WHERE PACKHEADER.OrderKey = @c_OrderKey
                AND PACKDETAIL.CartonNo = @c_CartonNo
                AND ( PACKDETAIL.LabelNo = ISNULL(RTRIM(@c_LabelNoParm),'') OR ISNULL(RTRIM(@c_LabelNoParm),'') = ''  ) --NJOW04
         END
      END

      --NJOW05
      IF @c_Apply_OrderDetailRef = '1'
         SET @n_MaxLineNo = 50
      ELSE IF @c_Apply_OrderDetailRef = '2'
         SET @n_MaxLineNo = 86  --NJOW10
      ELSE
         SET @n_MaxLineNo = 36

      OPEN GSI_Sku_Cur
      FETCH NEXT FROM GSI_Sku_Cur INTO @c_ParentSku, @c_Style, @c_Color, @c_Measurement, @c_Size, @c_Pack_Qty, @c_Sku , @c_RSku,
                                       @c_RetailComponentSKU, @c_RetailComponentQty, @c_CompStyle, @c_CompColor, @c_CompMeasurement, @c_CompSize  --NJOW05,10

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SET @n_licnt = @n_licnt + 1

         SET @n_TotalCartonUnitQty = @n_TotalCartonUnitQty + (CONVERT(INT, @c_Pack_Qty) * CONVERT(INT, @c_RetailComponentQty))   --(Wan02)

         IF @b_debug = 1
         BEGIN
            SELECT '@n_licnt: ' + ISNULL(RTRIM(@n_licnt),0) + ' - Updating Line Item info..'
            --SELECT @c_Style, @c_Color, @c_Measurement, @c_Size, @c_Pack_Qty, @c_Sku --AAY0020
            SELECT @c_Style, @c_Color, @c_Measurement, @c_Size, @c_Pack_Qty, @c_Sku, @c_RSku --AAY0020
         END

         IF @n_licnt <= @n_MaxLineno --50  --36 NJOW05
         BEGIN
            SET @c_licnt = RIGHT(RTRIM(REPLICATE('0', 2) + ISNULL(CAST(@n_licnt AS NVARCHAR(2)), '0')),2)

            --NJOW05
            IF CAST(@c_RetailComponentQty AS Int) = 0
               SET @c_RetailComponentQty = '1'

            IF @n_licnt <= 36 --NJOW05
            BEGIN
               IF @c_Apply_OrderDetailRef = '1'  -- NJOW05
               BEGIN
                  IF @c_ParentSku <> @c_PrevParentSku --NJOW10
                  BEGIN
                     SET @c_CartonLine1 = ISNULL(RTRIM(@c_CartonLine1),'') +
                                          ',"' + ISNULL(RTRIM(@c_Style),'') + '"' +
                                          ',"' + ISNULL(RTRIM(@c_Color),'') + '"' +
                                          ',"' + ISNULL(RTRIM(@c_Measurement),'') + '"' +
                                          ',"' + ISNULL(RTRIM(@c_Size),'') + '"' +
                                          ',"' + ISNULL(RTRIM(@c_Pack_Qty),'') + '"' +
                                          ',"' + ISNULL(RTRIM(@c_ParentSku),'') + '"' +  --NJOW10
                                          ',"' + ISNULL(RTRIM(@c_RSku),'') + '"'
                     SET @c_PrevParentSku = @c_ParentSku --NJOW10
                     SET @n_CartonLineItems = @n_CartonLineItems + 1
                  END

                  SET @c_CartonLine2 = ISNULL(RTRIM(@c_CartonLine2),'') +
                                    ',"' + ISNULL(RTRIM(@c_CompStyle),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompColor),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompMeasurement),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompSize),'') + '"' +
                                    ',"' + ISNULL(RTRIM(CAST((CAST(@c_Pack_Qty AS INT) * CAST(@c_RetailComponentQty AS INT)) AS NVARCHAR(10))),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Sku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RetailComponentSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_ParentSku),'') + '"' +  --NJOW10
                                    ',"' + ISNULL(RTRIM(CAST(@c_RetailComponentQty AS NVARCHAR(10))),'') + '"' +   --NJOW10
                                    ',""' + -- Reserve03
                                    ',""' + -- Reserve04
                                    ',""'   -- Reserve05
               END
               ELSE
               BEGIN  --@c_Apply_OrderDetailRef = '2','0'
                  SET @c_CartonLine1 = ISNULL(RTRIM(@c_CartonLine1),'') +
                                       ',"' + ISNULL(RTRIM(@c_Style),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_Color),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_Measurement),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_Size),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_Pack_Qty),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_Sku),'') + '"' +
                                       ',"' + ISNULL(RTRIM(@c_RSku),'') + '"'

                  SET @n_CartonLineItems = @n_CartonLineItems + 1
               END
            END

            --NJOW05 Update extended items - Start
            IF @c_Apply_OrderDetailRef = '1' AND @n_licnt > 36
            BEGIN
               SET @c_CartonLine2 = ISNULL(RTRIM(@c_CartonLine2),'') +
                                    ',"' + ISNULL(RTRIM(@c_CompStyle),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompColor),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompMeasurement),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_CompSize),'') + '"' +
                                    --',"' + ISNULL(RTRIM(CAST((CAST(@c_Pack_Qty AS INT) * CAST(@c_RetailComponentQty AS INT)) AS NVARCHAR(10))),'') + '"' +
                                    ',"' + ISNULL(RTRIM(CAST(@c_RetailComponentQty AS NVARCHAR(10))),'') + '"' +   --NJOW10
                                    ',"' + ISNULL(RTRIM(@c_Sku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RetailComponentSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_ParentSku),'') + '"' +  --NJOW10
                                    ',""' + -- Reserve02
                                    ',""' + -- Reserve03
                                    ',""' + -- Reserve04
                                    ',""'   -- Reserve05
            END

            --NJOW10
            IF @c_Apply_OrderDetailRef = '2' AND @n_licnt > 36
            BEGIN
               SET @c_CartonLine2 = ISNULL(RTRIM(@c_CartonLine2),'') +
                                    ',"' + ISNULL(RTRIM(@c_Style),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Color),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Measurement),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Size),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Pack_Qty),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_Sku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_RetailComponentSku),'') + '"' +
                                    ',"' + ISNULL(RTRIM(@c_ParentSku),'') + '"' +
                                    ',""' + -- Reserve02
                                    ',""' + -- Reserve03
                                    ',""' + -- Reserve04
                                    ',""'   -- Reserve05
            END

            --SELECT @n_TotalCartonQty = @n_TotalCartonQty + (CAST(@c_Pack_Qty AS Int) * CAST(@c_RetailComponentQty AS Int))
            SELECT @n_TotalCartonQty = @n_TotalCartonQty + CAST(@c_RetailComponentQty AS Int) --NJOW10
            --NJOW05 Update extended items - End
         END
         ELSE
         BEGIN -- IF @n_licnt > 50
            -- Insert duplicate record for line item > 50
            SET @n_PageNumber = @n_PageNumber + 1

            IF @b_debug = 1
            BEGIN
               SELECT '@c_OrderKey/@c_CartonNo/@n_PageNumber: ', @c_OrderKey + '/' + @c_CartonNo + '/' + @n_PageNumber
            END
         END
         FETCH NEXT FROM GSI_Sku_Cur INTO @c_ParentSku, @c_Style, @c_Color, @c_Measurement, @c_Size, @c_Pack_Qty, @c_Sku , @c_RSku, --AAY0020
                                          @c_RetailComponentSKU, @c_RetailComponentQty, @c_CompStyle, @c_CompColor, @c_CompMeasurement, @c_CompSize --NJOW05,10
      END -- END WHILE (@@FETCH_STATUS <> -1)

      CLOSE GSI_Sku_Cur
      DEALLOCATE GSI_Sku_Cur

      /*********************************************/
      /* Cursor Loop - Sku info extraction (End)   */
      /*********************************************/


     FETCH NEXT FROM GSI_Rec_Cur INTO
         @c_Case_Type,
         @c_Total_Units_This_Carton,
         @c_Sequential_Carton_Number,
         @c_Total_Cartons_Per_Store,
         @c_CartonTrackingNo,
         @c_Serial_SCC_Without_Check_Digit,
         @c_Serial_SCC_With_Check_Digit,
         @c_Total_Cartons_In_Shipment,
         @c_Carton_Weight,
         @c_Blank02,
         @c_Blank17,
         @c_Blank18,
         @c_Blank19,
         @c_Blank20,
         @c_Blank21,
         @c_Pick_Ticket_Suffix,
         @c_Reserve04,
         @c_Reserve05,
         @c_Reserve06,
         @c_Reserve07,
         @c_Reserve09,
         @c_Reserve10,
         @c_Reserve11,
         @c_Reserve12,
         @c_Reserve13

   END -- END WHILE (@@FETCH_STATUS <> -1)  GSI_Rec_Cur

   CLOSE GSI_Rec_Cur
   DEALLOCATE GSI_Rec_Cur
   /*********************************************/
   /* Cursor Loop - Record Level (Start)        */
   /*********************************************/
   /* Data extraction (End)                     */
   /*********************************************/

   --(Wan02) - START
   SET @c_File_Create_Date = CONVERT(VARCHAR(10), @n_TotalCartonUnitQty)
   SET @c_File_Create_Time = @c_SortCode
   --(Wan02) - END
/*********************************************/
/* Cursor Loop - XML Data Insertion (Start)  */
/*********************************************/
   DECLARE @n_FieldID   Int
         , @c_ColName   NVARCHAR(225)
         , @c_ColValues NVARCHAR(1000)
         , @n_ColID     Int
         , @n_ColCnt    Int
         , @n_LIColID   Int

   SET @n_FieldID   = 0
   SET @c_ColValues = ''
   SET @c_ColName   = ''
   SET @n_ColID     = 0
   SET @c_BuyerPO   = ''
   SET @n_LIColID   = 0

   IF @n_IsRDT = 1
   BEGIN
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('%BTW% /AF="' + ISNULL(RTRIM(@c_TemplateID),'') + '" /PRN="' + ISNULL(RTRIM(@c_PrinterID),'') + '" /PrintJobName="' + ISNULL(RTRIM(@c_LabelNo),'')+ '" /R=3 /C=1 /P /D="%Trigger File Name%" ', @@SPID)   -- (ChewKP04)

      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('%END%', @@SPID)
   END
   ELSE
   BEGIN
      INSERT INTO #TempGSICartonLabel_XML (LineText)
      VALUES ('%BTW% /AF="' + ISNULL(RTRIM(@c_TemplateID),'') + '" /PRN="' + ISNULL(RTRIM(@c_PrinterID),'') + '" /PrintJobName="' + ISNULL(RTRIM(@c_LabelNo),'')+ '" /R=3 /C=1 /P /D="%Trigger File Name%" ' ) -- (ChewKP04)
      INSERT INTO #TempGSICartonLabel_XML (LineText)
      VALUES ('%END%')
   END
        SET  @c_Page_Number = 1
        SET  @c_FullLineText =
              '"' + @c_Facility_Ship_From_Name               + '"' -- #1   Company
            +',"' + @c_Facility_Shipping_Address1            + '"' -- #2   Fac_Descr_1
            +',"' + @c_Facility_Shipping_Address2            + '"' -- #3   Fac_Descr_2
            +',"' + @c_Facility_Shipping_City                + '"' -- #4   Fac_Userdefine01
            +',"' + @c_Facility_Shipping_State               + '"' -- #5   Fac_Userdefine03
            +',"' + @c_Facility_Shipping_Zip                 + '"' -- #6   Fac_Userdefine04
            +',"' + @c_Storer_Name                           + '"' -- #7   S_Company
            +',"' + @c_Facility_Number          + '"' -- #8   Facility
            +',"' + @c_Blank01                               + '"' -- #9
            +',"' + @c_Blank02                               + '"' -- #10
            +',"' + @c_Carrier_Name                          + '"' -- #11  S_Company
            +',"' + @c_Proof_Of_Delivery                     + '"' -- #12  Not Mapped
            +',"' + @c_VICS_BOL                             + '"' -- #13  ExternMBOLKey
            +',"' + @c_Carrier_SCAC_Code                     + '"' -- #14  CarrierKey
            +',"' + @c_Non_VICS_BOL                          + '"' -- #15  MBOLKey
            +',"' + @c_Order_Session                         + '"' -- #16  Season Code (not Session)  --AAY025 ROUTING
            +',"' + @c_Blank03                               + '"' -- #17
            +',"' + @c_Blank04                               + '"' -- #18
            +',"' + @c_Blank05                               + '"' -- #19
            +',"' + @c_Ship_To_Consignee                     + '"' -- #20  Consigneekey
            +',"' + @c_Ship_To_Consignee_Name                + '"' -- #21  C_Company
            +',"' + @c_Ship_To_Consignee_Address1            + '"' -- #22  C_Address1
            +',"' + @c_Ship_To_Consignee_Address2            + '"' -- #23  C_Address2
            +',"' + @c_Ship_To_Consignee_City                + '"' -- #24  C_City
            +',"' + @c_Ship_To_Consignee_State               + '"' -- #25  C_State
            +',"' + @c_Ship_To_Consignee_Zip                 + '"' -- #26  C_Zip
            +',"' + @c_Ship_To_Consignee_ISOCntryCode        + '"' -- #27  C_ISOCntryCode  --AAY0023 #3
            +',"' + @c_Class_of_Service                      + '"' -- #28  M_Phone2        --AAY0023 #3
            +',"' + @c_Shipper_Account_No                    + '"' -- #29  M_Fax1          --AAY0023 #3
            +',"' + @c_Shipment_No                           + '"' -- #30  M_Fax2          --AAY0023 #3
            +',"' + @c_Final_Destination_Consignee_Name      + '"' -- #31  M_Company
            +',"' + @c_Final_Destination_Consignee_Address1  + '"' -- #32  M_Address1
            +',"' + @c_Final_Destination_Consignee_Address2  + '"' -- #33  M_Address2
            +',"' + @c_Final_Destination_Consignee_City      + '"' -- #34  M_City
            +',"' + @c_Final_Destination_Consignee_State     + '"' -- #35  M_State
            +',"' + @c_Final_Destination_Consignee_Zip       + '"' -- #36  M_Zip
            +',"' + @c_Final_Destination_Consignee_Store     + '"' -- #37  MarkForKey/Consigneekey  -- AAY003
            +',"' + @c_Buying_Store                          + '"' -- #38  B_BillToKey --AAY0019 from 6 to 15 Char
            +',"' + @c_Blank11                               + '"' -- #39
            +',"' + @c_Blank12                               + '"' -- #40
            +',"' + @c_Ship_To_Consignee_Zip2                + '"' -- #41  C_Zip
            +',"' + @c_Buying_Consignee_Zip                  + '"' -- #42  Blank
            +',"' + @c_Storer_Vendor_Num                     + '"' -- #43  UserDeifine05
            +',"' + @c_Buying_Consignee_Ship_To_Name         + '"' -- #44
            +',"' + @c_Buying_Consignee_Ship_To_Address1     + '"' -- #45 B_Address1
            +',"' + @c_Buying_Consignee_Ship_To_Address2     + '"' -- #46  B_Address2
            +',"' + @c_Buying_Consignee_Ship_To_City         + '"' -- #47  B_City
            +',"' + @c_Buying_Consignee_Ship_To_State        + '"' -- #48  B_State
            +',"' + @c_Buying_Consignee_Ship_To_Zip          + '"' -- #49  B_Zip
            +',"' + @c_Buying_Consignee_Region               + '"' -- #50  ISOCntryCode
            +',"' + @c_Purchase_Order_Number                 + '"' -- #51  ExternOrderKey
            +',"' + @c_Department_Number                     + '"' -- #52  UserDeifine03
            +',"' + @c_Department_Name                       + '"' -- #53  UserDeifine10
          +',"' + @c_PO_Type                               + '"' -- #54  ExternPOKey
            +',"' + @c_Case_Type                             + '"' -- #55  packinfo_CartonType
            +',"' + @c_Dock_Number                           + '"' -- #56  Door
            +',"' + @c_Product_Group                         + '"' -- #57  BUSR5
            +',"' + @c_PickUp_Date                           + '"' -- #58  MBOL.Userdefine07 --AAY0021
            +',"' + @c_Order_Product_Group                   + '"' -- #59  ORDERS.LabelPrice --AAY0022
            +',"' + @c_Carton_Weight                         + '"' -- #60  Carton Weight --AAY0023 #3
            +',"' + @c_Total_Units_This_Carton               + '"' -- #61  TotQty
            +',"' + @c_Duplicate_Label_Message               + '"' -- #62  AAY025 LOAD ID Orders.Userdefine01
            +',"' + @c_Julian_Day                            + '"' -- #63  Julian Day --AAY0023 #5
            +',"' + @c_Blank17                               + '"' -- #64
            +',"' + @c_Blank18                               + '"' -- #65
            +',"' + @c_Blank19                               + '"' -- #66
            +',"' + @c_Blank20                               + '"' -- #67
            +',"' + @c_Blank21                               + '"' -- #68
            +',"' + @c_Blank22                               + '"' -- #69
            +',"' + @c_Blank23                               + '"' -- #70
            +',"' + @c_Sequential_Carton_Number              + '"' -- #71  CartonNo (per store)
            +',"' + @c_Total_Cartons_Per_Store  + '"' -- #72  TotCarton (per store)
            +',"' + @c_Order_Start_Date                      + '"' -- #73  OrderDate
            +',"' + @c_Order_Completion_Date                 + '"' -- #74  DeliveryDate
            +',"' + @c_Bin_Location                          + '"' -- #75
            +',"' + @c_CartonTrackingNo                      + '"' -- #76 UPS/FedEx Carton Tracking # --AAY0023 #3
            +',"' + @c_PrintedBy                             + '"' -- #77
            +',"' + @c_MasterSKU                             + '"' -- #78  Retailer Master SKU
            +',"' + @c_SKUDept                               + '"' -- #79  Retailer SKU Dept #        --AAY010
            +',"' + @c_SKUProd                               + '"' -- #80  Retailer SKU PRoduct Group --AAY010
            +',"' + @c_Serial_SCC_Without_Check_Digit        + '"' -- #81  with formula
            +',"' + @c_Serial_SCC_With_Check_Digit           + '"' -- #82  with formula
            +',"' + @c_Total_Units_This_Carton_2             + '"' -- #83  TotSkuQty (If single sku in carton)
            +',"' + @c_GTIN_Code                             + '"' -- #84  Sku (If single sku in carton)
            +',"' + @c_Style_Description                     + '"' -- #85  SkuDescr (If single sku in carton) --AAY017
            +',"' + @c_Consignee_Item                        + '"' -- #86  RetailSku (If single sku in carton) --AAY025 16 to 20
            +',"' + @c_Style_Remark                          + '"' -- #87  Notes1
            +',"' + @c_Pack_Scale                            + '"' -- #88  PrePack Scale               --AAY0008
            --+',"' + @c_Pack_Qty                              + '"' -- #89  PrePack Qty Breakdown
            +',"' + @c_PP_Pack_Qty                              + '"' -- #89  PrePack Qty Breakdown   --AAY20120217
            +',"' + @c_Pack_Desc                             + '"' -- #90  PrePack Description
            +',"' + @c_Page_Number        + '"' -- #91
            +',"' + @c_Pick_Ticket_Number                    + '"' -- #92  BuyerPO  -- AAY001-#3
            +',"' + @c_File_Create_Date                      + '"' -- #93  @c_Date
            +',"' + @c_File_Create_Time                      + '"' -- #94  @c_Time
            +',"' + @c_Consignee_Account_Number              + '"' -- #95  StorerKey -- AAY004-#1
            +',"' + @c_Total_Number_Of_Cartons               + '"' -- #96  Apply TotalCarton above
            +',"' + @c_Sequential_Carton_Number_Ship         + '"' -- #97  CartonNo (per shiptment BY MBOL)
            +',"' + @c_Pick_Ticket_Suffix                    + '"' -- #98
            +',"' + @c_Total_Cartons_In_Shipment             + '"' -- #99  TotCartonByMbol (count CartonNo by MBOL)
            +',"' + @c_PackType                              + '"' -- #100 Pack Type --AAY006

   IF @b_debug = 1
   BEGIN
      PRINT '>>>> @c_FullLineText'
      PRINT @c_FullLineText
      PRINT '>>>> @c_CartonLine1'
      PRINT @c_CartonLine1
      PRINT '>>>> @c_CartonLine2'
      Print @c_CartonLine2
   END

   IF ISNULL(RTRIM(@c_CartonLine2),'') <> '' OR
      ISNULL(RTRIM(@c_Reserve01),'') <> '' OR
      ISNULL(RTRIM(@c_Reserve02),'') <> '' OR
      ISNULL(RTRIM(@c_Reserve03),'') <> '' OR
      ISNULL(RTRIM(@c_Reserve04),'') <> ''
   BEGIN
      SET @n_ColumnIdx = ISNULL(@n_CartonLineItems,1)
      WHILE @n_ColumnIdx <= 35
      BEGIN
         SET @c_CartonLine1 = ISNULL(RTRIM(@c_CartonLine1),'') + ',"","","","","","",""'
         SET @n_ColumnIdx = @n_ColumnIdx + 1
      END
   END

   SET @c_FullLineText = @c_FullLineText
        + ISNULL(RTRIM(@c_CartonLine1),'')
        + ',"' + ISNULL(RTRIM(@c_Reserve01),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve02),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve03),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve04),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve05),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve06),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve07),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve08),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve09),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve10),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve11),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve12),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve13),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_RCCGroup),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_MisclFlag),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve16),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve17),'') + '"'
        + ',"' + ISNULL(RTRIM(@c_Reserve18),'') + '"'
        + ISNULL(RTRIM(@c_CartonLine2),'')

      --NJOW07
      IF @n_IsRDT = 1
         INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
          VALUES (@c_FullLineText, @@SPID)
      ELSE
         INSERT INTO #TempGSICartonLabel_XML (LineText)
          VALUES (@c_FullLineText)

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

IF @c_FileName = 'TEMPDB' --NJOW01
BEGIN
   IF OBJECT_ID('tempdb..#TMP_GSICartonLabel_XML') IS NOT NULL
   BEGIN
      INSERT INTO #TMP_GSICartonLabel_XML              SELECT * FROM #TempGSICartonLabel_XML
      ORDER BY seqno
   END
END
ELSE
BEGIN
   IF @n_IsRDT <> 1
      -- Select list of records
      SELECT SeqNo, LineText FROM #TempGSICartonLabel_XML
END

END

GO