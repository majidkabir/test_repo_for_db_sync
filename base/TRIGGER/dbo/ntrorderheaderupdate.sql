SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Trigger: ntrOrderHeaderUpdate                                         */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:                                                              */
/*                                                                       */
/* Called By: When Udpate Order Header Record                            */
/*                                                                       */
/* PVCS Version: 4.11                                                    */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver.  Purposes                                 */
/* 11-Sep-2002  RickyYee  1.0   Merge code from SOS, FBR and Performance */
/*                              tuning from July 13th till Aug 23th      */
/* 01-Oct-2002  RickyYee  1.0   To include update of loadplan when       */
/*                              status='5', to cater for the cancelled   */
/*                              orders                                   */
/* 03-Oct-2002  RickyYee  1.0   To fix the closed orderm so the status   */
/*                              is set to 9 when sostatus = '9'          */
/* 03-Oct-2002  RickyYee  1.0   To fix update of status based on         */
/*                              sostatus and place it at the end of the  */
/*                              script                                   */
/* 17-Oct-2002  RickyYee  1.0   To fix the delete of the last            */
/*                              orderdetail line from the Order, so that */
/*                              no error msg is popup to prevent the     */
/*                              deletion (SOS7927)                       */
/* 07-Nov-2002  RickyYee  1.0   To fix the Order Status update to be in  */
/*                              sync with the Orderdetail and so that    */
/*                              loadplandetail and loadplan have the     */
/*                              correct status                           */
/* 21-Nov-2002  Vicky     1.0   1) Patched modification by Wally for     */
/*                                IDSPH - Consider Freegoodqty (SOS8647) */
/*                              2) Included IDSTH PMTL SO Export insert  */
/*                                 record to transmitlog                 */
/* 11-Dec-2002  RickyYee  1.0   Changes for IDSTH V5 Upgrade             */
/* 15-Jan-2003  RickyYee  1.0   To include the null value checking for   */
/*                              freegood qty b4 calculcate the status    */
/* 24-Jan-2003  Wally     1.0   Status update for cancellation orders    */
/*                              (SOS9506)                                */
/* 07-Mar-2003  RickyYee  1.0   New changes from Wally for Trigantic     */
/* 25-Mar-2003  June      1.0   Fixes for PH OW                          */
/* 25-Jul-2003  YokeBeen  1.0   IDSTH JDH EC (SOS11488)                  */
/* 21-Aug-2003 Shong     1.0   Fuji Malaysia Interface (SOS9331)        */
/* 03-Sep-2003  Shong     1.0  Bug fixing                               */
/* 11-Sep-2003  Wally     1.0   SOS10083                        */
/* 23-Sep-2003  Wally     1.0   Trigantic changes */
/* 28-Nov-2003  Wally     1.0   Fixes for Watsons (PH) order processing  */
/*                              revisions                                */
/* 01-Dec-2003  Shong     1.0   Performance Tuning                       */
/* 03-Dec-2003  Wally     1.0   Fix Watsons partial ship status          */
/* 05-Jan-2004  RickyYee  1.0   To fix update of SOSTATUS to 'CANC' with */
/*                              adding the checking of the @n_continue   */
/*                              before proceed to do the PMTL Interface  */
/*                              record, to cause @n_err to return '0'    */
/* 20-Jan-2004  Shong     1.0   Ship to address doesn't change when      */
/*                              Consigneekey change (SOS19292)           */
/* 18-Feb-2004  Wally     1.0   Orders belonging to same ExternOrderKey  */
/*                              Closes upon MBOL (SOS20027)              */
/* 18-Feb-2004  Shong     1.0   Thailand Performance Tuning              */
/* 19-Feb-2004  Shong     1.0   Check @n_success when calling other SP   */
/* 18-Mar-2004  MaryVong  1.0   NZMM - Shipment Confirmation Export      */
/*                              (SOS18999)                               */
/* 18-Mar-2004  MaryVong  1.0   Remove undeclared variable               */
/*                              @c_InsertStorerKey                       */
/* 18-Mar-2004  Shong     1.0   Add NSC Stop Order Interface             */
/* 24-Mar-2004  Shong     1.0   NSC Changes for Short Ship Order         */
/* 08-Apr-2004  MaryVong  1.0   Check-in for Jeff -Mandom pick confirm   */
/* 13-Apr-2004  Shong     1.0   Include Loreal interface                 */
/* 27-Apr-2004  Shong     1.0   Performance Tuning                       */
/* 27-Apr-2004  June      1.0   Bug fixes-MY FUJIMYORD export (SOS22457) */
/* 14-Jun-2004  June      1.0   On site changes by Wally                 */
/* 18-Jun-2004  MaryVong  1.0   IDSHK-Nuance Watson (Modified by Ricky)  */
/* 18-Jun-2004  June      1.0   IDSPH ULP, new interface 'ULPSOCANC'     */
/*                              (SOS21780)                               */
/* 05-Aug-2004  Shong     1.0   Remove PickHeader when all pickdetail    */
/*                              are deleted (Qtyallocated+QtyPicked)=0   */
/* 09-Sep-2004  MaryVong  1.0   Loreal Orders Confirm - Create record    */
/*                              for CANC data (SOS26923)                 */
/* 06-Oct-2004  Shong     1.0   Changes for Taiwan Unilever Project      */
/* 03-Nov-2004  RickyYee  1.0   Change make for NW to use Transmitlog3   */
/*                              table - Changes By IDSHK ML Transmitlog3 */
/*                              (SOS27626)                               */
/* 03-Nov-2004  RickyYee  1.0   Changes for Carrefour Gold Interface     */
/* 04-Mar-2005  YTWan     1.0   No Despatch Advise if Direct Shipped     */
/*                              (SOS33006)                               */
/* 04-Mar-2005  June      1.0   SOS22726 - CIBAITF                       */
/* 08-Mar-2005  MaryVong  1.0   Create PickConfirm Interface configkey   */
/*                              'PICKCFMITF' for general used (SOS32009) */
/* 15-Mar-2004  Shong     1.0   Check-In for Ricky,Status will not       */
/*                              reverse to                               */
/*                              Normal when Pick-In-Progress         */
/* 08-Mar-2005  MaryVong  1.0   1) SG Maxxium - Pick Confirm (SOS30121)  */
/*                              2) SG Maxxium - Shipment Order Confirm   */
/*                                    (SOS30126)               */
/* 27-May-2005  June      1.0   Trap Errmsg if failed to update          */
/*                              TriganticLog                             */
/* 31-May-2005  MaryVong  1.0   Add in checking on 'CANC' (SOS22726)     */
/* 01-Jun-2005  June      1.0   SOS34759 - disallow changing of SOStatus */
/*                              to 'CANC' if there is pending pickdetail */
/* 09-Jun-2005  Shong     1.0   Include Generic Ship Confirm Interface   */
/*                              Flag SOCFMLOG                            */
/* 27-Jun-2005  WTShong   1.0   Conver MIN to Cursor-Performance Tuning  */
/* 14-Sep-2005  Vicky     1.0   1) SOS#39993 - Insertion of Order.Status */
/*                                 as Key2 in Triganticlog table         */
/*                        1.0   2) SOS#39993 - Insert new line to        */
/*                                 Triganticlog table for every new      */
/*                                 order status update instead of        */
/*                                 updating of existing transmitflag     */
/*                                 back to 0                             */
/* 10-Oct-2005  MaryVong  1.0   SOS41481 CIBA - Order Confirm Export Do  */
/*                              not interface for Type = 'KITTING'       */
/* 11-Oct-2005  Vicky     1.0   Add in Generic PickConfirm Interface     */
/*                              configkey 'PICKCFMLOG'                   */
/* 21-Nov-2005  MaryVong  1.0   SOS42858 Bug Fixed - Not allow to cancel */
/*                              orders if it exists in PickDetail        */
/* 27-Dec-2005  Vicky     1.0   Change the data length for status        */
/*                              insertion to Triganticlog.Key2           */
/* 17-Jan-2006  Vicky     1.0   Added in table linkage between Inserted  */
/*                              & Deleted during Trigantic Update        */
/* 27-Apr-2006  Vicky     1.0   Add in Ordertype as Key2 for SOCFMLOG    */
/* 25-Jul-2006  Shong     1.0   Insert record into TMSLog for Interface. */
/*                              (SOS53821) - (Shong001)                  */
/* 08-Mar-2007  MaryVong  1.0   SOS66675 Add in Generic Cancelled Order  */
/*                              Interface configkey 'CANCSOLOG'          */
/* 06-Feb-2007  June      1.0   SOS66030 - Change "NZPICKCONF" to        */
/*                              Transmitlog3 Table                       */
/* 21-Sep-2007  James     1.0   SOS80697 - Add 'M' or 'D' as Key2 into   */
/*                              ispGenTMSLog for TMSHK                   */
/* 04-Jun-2008  MaryVong  1.0   FBR107528 Add POS Interface configkey    */
/*                              'POSITF' (Set TransmitLog3.Tablename =   */
/*                              'WMSPOS')                                */
/* 17-Jul-2008  YokeBeen  1.1   SOS#111333-New trigger point for IDSTW   */
/*                              LOR for the Pick Confirmation Outbound.  */
/*                              Records to be triggered when             */
/*                              ORDERS.Status = "CANC".                  */
/*                              Tablename = "PICKINPROG". -(YokeBeen01)  */
/* 30-Jul-2008  MCTANG    1.2   SOS#110280 Vital WMS Ship Confirm.       */
/* 21-Oct-2008  YokeBeen  1.3   SOS#117725 - New trigger point for IDSMY */
/*                              BBraun -> Configkey = "PREINVLOG".       */
/*                         - (YokeBeen02)                           */
/* 16-Feb-2009  Leong     1.4   SOS#129033 - Change trigger PICKCFMLOG   */
/*                              upon status update only                  */
/* 27-Aug-2009  YokeBeen  1.5   SOS#145404 - Added new trigger point -   */
/*                              "SOCFMWOW" for WOW (Web Ordering).       */
/*                              - (YokeBeen03)                           */
/* 28-Aug-2009  ChewKP    1.6   SOS#143271 - Update ExternOrderkey       */
/*                  (ChewKP01)                               */
/* 10-Sept-2009 TLTING    1.6  SOS146709 Set Trigantic intf mandatory    */
/*                              (tlting01)                               */
/* 10-Sept-2009 TLTING    1.6  put back Editwho&EditDate update         */
/*                             (tlting02)                                */
/* 20-Jan-2010  TLTING    1.6   trace info                               */
/* 17-May-2010  TLTING    1.7   NOT Allow cancel when Pre allocated      */
/*                               -tlting03                               */
/* 03-Jun-2010  MCTang    1.8   SOS#172970 - Added new trigger point -   */
/*                              "SOCANCCMS" for CMS. (MC01)              */
/*                        1.8   SOS#174714 - Added new trigger point -   */
/*                              "SO3PLLOG" for 3PL. (MC02)               */
/*                        1.8   SOS#172879 - Added new trigger point -   */
/*                              "SOCFM2LOG" for Alternate. (MC03)        */
/* 04-Aug-2010  MCTang    1.9   SOS#171477 - Added new trigger point -   */
/*                              "LORADV" - Loreal Anti-Diversion.(MC04)  */
/* 17-Aug-2010  Shong     1.91  Cancel Checking only apply to pickdetail */
/*                              with qty > 0  (Shong01)                  */
/* 18-Nov-2010  James     1.91  Cancel update if SOStatus in             */
/*                              ('9', 'CANC') (james01)                  */
/* 04-Aug-2010  MCTang    1.10  Add new trigger point 'VPACKLOG'(MC05)   */
/* 18-May-2010  MCTang    1.10  Add new trigger point 'PICKINMAIL'(MC06) */
/* 28-Oct-2011  GTGOH     1.12  Change no to update B_Vat no value for   */
/*                              CreditLimit (GOH01)                      */
/* 24-FEB-2012  YTWan     1.13  SOS#236323: Default Orders.Userdefine08  */
/*                              base on Storercfg = 'KITDSCPICK'.(Wan01) */
/* 12-Jan-2012  MCTang    1.14  Add new trigger point'SOShpCfmCMS'(MC07) */
/* 04-May-2012  Leong     1.15  SOS# 242563 - Bug Fix                    */
/* 08-May-2012  TLTING    1.16  SOS# 243459 - Update orderdetail ststus  */
/*                              base on orders.status (tlting04)         */
/* 22-May-2012  TLTING03  1.17  DM integrity - add update editdate B4    */
/*                              TrafficCop for status < '9'              */
/* 29-Aug-2012  TLTING    1.18  Bug fix on Loop Orderkey (tlting04)      */
/* 06-Sep-2012  KHLim     1.19  Move up ArchiveCop (KH01)                */
/* 25-Sep-2012  SHONG     1.20  SOS# 256343 - CANC reverse back to 0     */
/*                              when any column changed.                 */
/* 28-Sep-2012  Audrey    1.20  SOS# 240265 - Allow CANC without         */
/*                              pickdetail(ang01)                        */
/* 12-Dec-2012  MCTang    1.21  Add new trigger point 'REINSTTL3' (MC08) */
/* 29-Jan-2013  TLTING    1.22  Storerconfig turn Off trigantic(TLTING02)*/
/* 15-MAY-2013  YTWan     1.23  SOS#276826-VFDC SO Cancel.(Wan02)        */
/* ***********************************************************************/
/*                              Base on PVCS SQL2005_Unicode version 1.2 */
/* 07-NOV-2013  Chee      1.4   Bug Fixed on SOS#276826-VFDC SO Cancel.  */
/*                              (Chee01)                                 */
/* 28-Oct-2013  TLTING    1.5   Review Editdate column update            */
/* 02-Aug-2013  GTGOH     1.6   SOS#291603 - Remark insert SHPADVMSF and */
/*                              PICKMSF to Transmitlog2 (GOH02)          */
/* 11-Mar-2014  KTLow     1.7   SOS#299158 - Add in Courier Interface    */
/*                              Interface During Order Cancellation with */
/*                              configkey 'WSCRSOCANC' (KT01)        */
/*                              SOS#299158 - Add in Courier Interface    */
/*                              Interface During Ship Confirm With       */
/*                              configkey 'WSCRSOCFM' and 'WSCRSOCFM2'   */
/*                              (KT01)                                   */
/* 07-Aug-2014  Shong     1.8   Added Generic Trigger for Interface      */
/* 18-Aug-2014  MCTang    1.9   Enhance Generaic Trigger for Interface   */
/*                              when status feild Update (MC09)          */
/* 09-Sep-2014  TLTING    2.0   Doc Status Tracking Log TLTING05         */
/* 10-Sep-2014  TLTING    2.1   SOS319233-Not allow edit Delivery Date   */
/* 06-Mar-2015  NJOW01    2.2   315021-Call order custom cancel stored   */
/*                              proc                                     */
/* 23-Apr-2015  MCTang    2.3   Enhance Generaic Trigger Interface(MC10) */
/* 11-May-2015  TLTING    2.4   Disable Trigantics                       */
/* 15-Jun-2015  TLTING    2.5   Deadlock Tune                            */
/* 27-Aug-2015  SPChin    2.6  SOS350474 - Include Zone = '8' When       */
/*                                          Remove PickHeader            */
/* 07-Sep-2015  TLTING06  2.7   Performance Tune                         */
/* 20-Sep-2015  SHONG02   2.8   Added StorerConfig                       */
/*                              SetSOStatusWhileStatusChange             */
/* 02-OCT-2015  NJOW02    2.9  354034 - call custom stored proc          */
/* 15-JAN-2016  Leong     3.0  SOS360858 - Remove NonTRIGANTIC configkey.*/
/* 27-SEP-2016  Wan03     3.1  SOS#361901 EPACK-Performance.             */
/* 30-SEP-2016  TLTING    3.1  SET OPTION                                */
/* 10-Nov-2016  TLTING07  3.1  Bug fix change SOstatus                   */
/* 12-May-2017  NJOW03    3.2  WMS-1742 Move call custom sp to bottom    */
/*                             to be able get the updated status.        */
/*                             Trafficcop mode still allow run custom    */
/*                             trigger sp if the config is turned on.    */
/* 19-MAY-2017  WAN04     3.3  WMS-1720 - ECOM Nov11 - Fixed Issue       */
/* 10-Aug-2017  TLTING08  3.4  Performance Tune- Missing NOLOCK          */
/* 11-AUG-2017  WAN05     3.5  WMS-2306 - CN-Nike SDC WMS ECOM Packing CR*/
/* 22-Aug-2017  NJOW04    3.6  WMS-2749 SetSOStatusWhileStatusChange     */
/*                             include priority filtering. Trafficcop    */
/*                             mode still allow run.                     */
/* 09-Nov-2017  TLTING09  3.7  temp single\Multi Orders                  */
/* 10-Nov-2017  Wan06     3.8  Webservice update ORders.SOStatus with    */
/*                             Trafficcop = null                         */
/* 26-Mar-2018  TLTING10  3.9  Single\Multi Orders                       */
/* 27-Jul-2018  MCTang    4.0  Enhance Generaic Trigger Interface (MC11) */
/* 24-Apr-2018  NJOW05    4.1  WMS-4743 SetSOStatusWhileStatusChange     */
/*                             change priority to ecom_presale_flag      */
/* 18-Jul-2018  NJOW06    4.2  WMS-5774 Storerconfig DSCPICK support     */
/*                             facility                                  */
/* 10-Oct-2018  TLTING    4.1  Remove row lock                           */
/* 28-Jan-2019  TLTING_ext  4.2  exlarge externorderkey field length     */
/* 17-Dec-2019  WLChooi   4.3  WMS-11359 - Modify VF Cancellation logic  */
/*                             to cater for ECOM wave (WL01)             */
/* 13-Aug-2020  TLTING11  4.4  E, clear trackingno If Shipperkey change  */
/* 22-Sep-2020  NJOW07    4.5  WMS-15238 ValidateSOStatus_SP & ispVSOST01*/
/*                             check exclude doctype = 'E'               */
/* 16-Dec-2020  TLTING12  4.6  WMS-15510 tracking DSTORSSOSTATUS         */
/* 05-May-2021  Wan07     4.7  LFWM-2723 - RGMigrate Allocation schedule */
/*                             job to QCommander. Calculate Wave Status  */
/* 17-Feb-2022  YTWan     4.8  Fix Wave.status not sync with             */
/*                             Orders.status      - (JSM-51565)          */
/* 19-May-2022  WLChooi   4.9  DevOps Combine Script                     */
/* 19-May-2022  WLChooi   4.9  WMS-19687 - Filter UDF03 = ECOM_Platform  */
/*                             (WL02)                                    */
/* 19-May-2022  WLChooi   4.10 WMS-19704 - TrafficCopAllowITFTriggerCfg  */
/*                             (WL03)                                    */
/* 21-Jun-2022  TLTING13  4.11 Update Status 9 data - skip trigger script*/
/* 06-Sep-2024   PPA371    4.12 Validate if status is cancel             */
/*************************************************************************/

CREATE   TRIGGER [dbo].[ntrOrderHeaderUpdate]
ON  [dbo].[ORDERS]
FOR UPDATE
AS
IF @@ROWCOUNT = 0
BEGIN
   RETURN
END

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
          @b_Success                   int       -- Populated by calls to stored procedures - was the proc successful?
,         @n_err                       int       -- Error number returned by stored procedure or this trigger
,         @n_err2                      int       -- For Additional Error Detection
,         @c_errmsg                    NVARCHAR(250) -- Error message returned by stored procedure or this trigger
,         @n_continue                  int
,         @n_starttcnt                 int       -- Holds the current transaction count
,         @c_preprocess                NVARCHAR(250) -- preprocess
,         @c_pstprocess                NVARCHAR(250) -- post process
,         @n_cnt                       int
-- Added By Ricky For IDSV5 -- start
,         @c_orderkey                  NVARCHAR(10)
-- Added By Ricky For IDSV5 -- End
,         @c_PrevFacility              NVARCHAR(5)
,         @c_Facility                  NVARCHAR(5)
,         @c_PrevStorerKey             NVARCHAR(15)
,         @c_Storerkey                 NVARCHAR(15)
,         @c_SOStatus                  NVARCHAR(10)
,         @c_CurSOStatus               NVARCHAR(10)
,         @c_PreSOStatus               NVARCHAR(10)
,         @n_OpenQty                   int
,         @c_authority                 NVARCHAR(1)
,         @c_authority_pmtl            NVARCHAR(1)
,         @c_authority_owitf           NVARCHAR(1)
,         @c_authority_fujiitf         NVARCHAR(1)
,         @c_authority_pkitf           NVARCHAR(1)
,         @c_authority_dscpick         NVARCHAR(1)
,         @c_authority_mandommy        NVARCHAR(1)
,         @c_authority_nwitf           NVARCHAR(1)
,         @c_authority_c4itf           NVARCHAR(1)
,         @c_OrdType                   NVARCHAR(10)
,         @c_PrevSTATUS                NVARCHAR(10)
,         @c_Status                    NVARCHAR(10)
,         @c_UserDefine08              NVARCHAR(10)
,         @c_ContainerType             NVARCHAR(20)
,         @n_ContainerQty              int
,         @c_Issued                    NVARCHAR(1)
,         @c_OrderLineNumber           NVARCHAR(5)
,         @n_Qtytobill                 int
,         @n_BilledContainerQty        int
,         @c_ExternOrderKey        NVARCHAR(50)  --tlting_ext
,         @c_NZShort                   NVARCHAR(10) -- NZMM ShipConfirm Interface (SOS18999) -Start(1)
,         @c_authority_nzmmitf         NVARCHAR(1)  -- NZMM ShipConfirm Interface (SOS18999) -End(1)
,         @c_authority_nkreg           NVARCHAR(1)  -- Added by SHONG FOR NSC Interface
,         @c_authority_lorealitf       NVARCHAR(1)
,         @c_authority_ulpitf          NVARCHAR(1)  -- IDSPH ULP Cancel Order Interface (SOS21780)
,         @c_lastloadflag              NVARCHAR(1)
,         @c_authority_utlitf          NVARCHAR(1)  -- Taiwan Unilever Interface
,         @c_authority_pickcfmitf      NVARCHAR(1) -- General PickConfirm Interface (SOS32009)
,         @c_authority_msfitf          NVARCHAR(1)  -- SG Maxxium Interface (SOS30121 & 30126)
,         @c_authority_socfm           NVARCHAR(1)  -- Generic Ship Confirm Interface
,         @c_authority_cancso          NVARCHAR(1)  -- Generic Cancelled Order Interface
,         @c_authority_crcancso        NVARCHAR(1)  -- (KT01)
,         @c_authority_crshpcfm        NVARCHAR(1)  -- (KT01)
,         @c_authority_crshpcfm2       NVARCHAR(1)  -- (KT01)
,         @c_authority_canccmsso       NVARCHAR(1)  -- (MC01)
,         @c_authority_so3pl           NVARCHAR(1)  -- (MC02)
,         @c_authority_socfm2          NVARCHAR(1)  -- (MC03)
,         @c_authority_LorAdv          NVARCHAR(1)  -- (MC04)
,         @c_authority_VPackLog        NVARCHAR(1)  -- (MC05)
,         @c_authority_PickInMail      NVARCHAR(1)  -- (MC06)
,         @c_authority_SOShpCfmCMS     NVARCHAR(1)  -- (MC07)
,         @c_authority_REInstTL3       NVARCHAR(1)  -- (MC08)
,         @c_Specialhandling           NVARCHAR(1)
,         @c_authority_positf          NVARCHAR(1)  -- FBR107528 POS Interface
,         @cOrdKey                     NVARCHAR(10)
,         @c_TriganticLogkey           NVARCHAR(10)
,         @cTransFlag                  NVARCHAR(1)
,         @c_upordstatus               NVARCHAR(4)
,         @c_deletedstatus             NVARCHAR(4)
,         @c_authority_pickcfmlog      NVARCHAR(1) -- Generic PickConfirm Interface
-- (SOS53821) - (Shong001)
,         @c_RoutingTool               NVARCHAR(30)
,         @c_OldRoutingTool            NVARCHAR(30)
,         @c_Tablename                 NVARCHAR(30)
,         @c_authority_tms             NVARCHAR(1)
-- (SOS80697) for TMSHK
,         @c_Route                     NVARCHAR(10)
,         @c_authority_pickinprog      NVARCHAR(1)    -- (YokeBeen01)
,         @c_authority_vshplog         NVARCHAR(1)    -- MCTANG SOS#110280
,         @c_authority_preinvitf       NVARCHAR(1)    -- (YokeBeen02)
,         @c_authority_socfmwow        NVARCHAR(1)    -- (YokeBeen03)
,         @c_PreConsigneekey           NVARCHAR(15)   -- (YokeBeen03)
,         @c_Consigneekey              NVARCHAR(15)   -- (YokeBeen03)
,         @c_PrevExternOrderKey        NVARCHAR(50)    --tlting_ext -- (ChewKP01)
,         @cOrderLineNumber            NVARCHAR(5)    -- (tlting01)
,         @c_KitDSCPick                NVARCHAR(10)   -- (Wan01)
,         @b_CustomSOCanc          INT            -- (Wan02)
,         @c_authority_XFieldEdit      NCHAR(1)
,         @c_StatusUpdated             CHAR(1)        -- (MC09)
,         @c_COLUMN_NAME               VARCHAR(50)    -- (MC09)
,         @c_ColumnsUpdated            VARCHAR(1000)  -- (MC09)
,         @c_delstatus                 NVARCHAR(10)
,         @c_Loadkey                   NVARCHAR(10)
,         @c_SetSOStatusWhileStatusChange NCHAR(1)       -- SHONG002
,         @c_NewSOStatus                  NVARCHAR(10)
,         @c_DocType                      NVARCHAR(2)

,        @b_UpdatePackTaskDetail          INT            --(Wan03)
,        @n_RowRef                        BIGINT         --(Wan03)
,        @c_TaskBatchNo                   NVARCHAR(10)   --(Wan03)
,        @c_DelSOStatus                   NVARCHAR(10)   --(Wan04)
,        @c_Status_PTD                    NVARCHAR(10)   --(Wan04)
,        @c_DELStatus_PTD                 NVARCHAR(10)   --(Wan04)
,        @c_PickSlipNo                    NVARCHAR(10)   --(Wan05)
,        @c_PackStatus                    NVARCHAR(10)   --(Wan05)
,        @c_TrafficCopAllowTriggerSP      NVARCHAR(10)   --NJOW03
,        @c_ECOM_PRESALE_FLAG             NVARCHAR(2)    --NJOW05
,        @c_TrafficCopAllowSOStatusUpd    NVARCHAR(10)   --NJOW04
,        @c_SINGLE_Multi_Flag                       NCHAR(1) = ''
,        @c_TrafficCopAllowEPACKStatusUpd NVARCHAR(10)   --(Wan06)
,        @c_Trackingno                    NVARCHAR(40)   --tlting11
,        @c_Authority_DSTORSSOSTATUS      NCHAR(1)      -- TLTING12
,        @c_upordSOstatus                 NVARCHAR(10)
,        @c_deletedSOstatus               NVARCHAR(10)
,        @c_ECOM_Platform                 NVARCHAR(30)   --WL02
,        @c_TrafficCopAllowITFTriggerCfg  NVARCHAR(10)   --WL03

   DECLARE   @n_debug int
   DECLARE   @c_OrdStatus NVARCHAR(4)
   SET @n_continue = 1
   SET @n_debug = 0

   SET @c_KitDSCPick    = ''                 -- (Wan01)
   SET @b_CustomSOCanc  = 0                  -- (Wan02)
   SET @c_StatusUpdated = 'N'                -- (MC09)
   SET @c_NewSOStatus = ''
   SET @c_TrafficCopAllowEPACKStatusUpd = 'N'            --(Wan06)

   DECLARE @b_ColumnsUpdated VARBINARY(1000)
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()


-- Added before TrafficCop
-- To Make sure it's still trigger the Transmitflag
-- Added By SHONG
-- BEGIN

-- SOS#39993 - Insertion of Orders.Status to Key2 in Triganctilog table
--           - Insertion of new lines to Triganticlog table when status update
--             instead of updating the transmitflag back to 0 again
--           - Bug fixing for current script
-- Modified By Vicky on 14th Sept 2005


IF (UPDATE(Status) OR UPDATE(SoStatus))
BEGIN
   -- TLTING05    TLTING02 -- tlting01

   -- IF NOT EXISTS( SELECT 1 FROM INSERTED, StorerConfig WITH (NOLOCK)
   --             WHERE  StorerConfig.StorerKey = INSERTED.StorerKey
   --               AND ConfigKey = 'NonTRIGANTIC' AND sValue = '1') -- SOS360858
   -- BEGIN
      SELECT @cOrdKey = SPACE(10)
      SELECT @c_upordstatus = SPACE(4)
      SELECT @c_deletedstatus = SPACE(4)
      SELECT @c_delstatus = ''
      SET @c_upordSOstatus =''
      SET @c_deletedSOstatus = ''

      DECLARE OrdCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT INSERTED.OrderKey, INSERTED.Status, DELETED.Status, INSERTED.Storerkey,
            ISNULL(RTRIM(INSERTED.SoStatus),''), ISNULL(RTRIM(DELETED.SoStatus),'')
      FROM   INSERTED, DELETED
      WHERE  INSERTED.Orderkey = DELETED.Orderkey
      AND ( (INSERTED.Status <> DELETED.Status) OR ( INSERTED.SoStatus <> DELETED.SoStatus ))

      OPEN OrdCur

      WHILE 1=1 -- @@FETCH_STATUS <> -1
      BEGIN
         FETCH NEXT FROM OrdCur INTO @cOrdKey, @c_upordstatus, @c_deletedstatus, @c_Storerkey, @c_upordSOstatus, @c_deletedSOstatus

        IF @@FETCH_STATUS = -1
            BREAK

         IF @c_upordstatus <> @c_deletedstatus
         BEGIN
            --TLTING05
            IF EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK) WHERE DocumentNo = @cOrdKey
                          AND DocStatus = @c_upordstatus and Tablename = 'STSORDERS')
            BEGIN
               SELECT @c_delstatus = @c_deletedstatus
            END
            ELSE
            BEGIN
               SELECT @c_delstatus = ''
            END

            EXEC ispGenDocStatusLog 'STSORDERS', @c_Storerkey, @cOrdKey, '', @c_delstatus, @c_upordstatus
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

            IF NOT @b_success=1
            BEGIN
               SELECT @n_continue=3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Insert Into DocStatusTrack Table (ORDERS) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END

         -- TLTING12
         -- DSTORSSOSTATUS
         IF @n_continue=1 OR @n_continue = 2
         BEGIN

            IF (@c_upordSOstatus <> @c_deletedSOstatus)
            BEGIN
               SELECT @b_success = 0
               EXECUTE dbo.nspGetRight  '',       -- Facility
                        @c_Storerkey,             -- Storer
                        '',                       -- Sku
                        'DSTORSSOSTATUS',               -- ConfigKey
                        @b_success                OUTPUT,
                        @c_Authority_DSTORSSOSTATUS     OUTPUT,
                        @n_err                    OUTPUT,
                        @c_errmsg                 OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=63901
                  SELECT @c_errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (DSTORSSOSTATUS) Failed (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
               ELSE
               BEGIN
                  IF @c_Authority_DSTORSSOSTATUS = '1'
           BEGIN
                     EXEC ispGenDocStatusLog 'DSTORSSOSTATUS', @c_Storerkey, @cOrdKey, '', @c_deletedSOstatus, @c_upordSOstatus
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END -- @@c_Authority_DSTORSSOSTATUS = '1'
               END -- IF @b_success = 1
            END
         END -- IF @n_continue=1 OR @n_continue = 2


         FETCH NEXT FROM OrdCur INTO @cOrdKey, @c_upordstatus, @c_deletedstatus, @c_Storerkey, @c_upordSOstatus, @c_deletedSOstatus
      END -- WHILE
      CLOSE OrdCur
      DEALLOCATE OrdCur
   -- END -- If exists -- SOS360858
END
-- end SOS#39993

-- TraceInfo (tlting01) - Start
DECLARE @d_starttime    datetime,
        @d_endtime      datetime,
        @d_step1        datetime,
        @d_step2        datetime,
        @d_step3        datetime,
        @d_step4        datetime,
        @d_step5        datetime,
        @c_col1         NVARCHAR(20),
        @c_col2         NVARCHAR(20),
        @c_col3         NVARCHAR(20),
        @c_col4         NVARCHAR(20),
        @c_col5         NVARCHAR(20),
        @c_TraceName    NVARCHAR(80),
        @c_step5        NVARCHAR(20)

DECLARE @c_NSQLValue NVARCHAR(30)

SET @d_starttime = GETDATE()
SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

IF UPDATE(ArchiveCop)      --KH01
BEGIN
   SELECT @n_continue = 4
END

IF @n_continue=1 or @n_continue=2   --KH01
BEGIN
   -- tlting01
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
        WHERE INSERTED.OrderKey = DELETED.OrderKey
               AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) )
      AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE ORDERS
      SET    EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
           , TrafficCop = NULL
      FROM  ORDERS,INSERTED
      WHERE ORDERS.OrderKey = INSERTED.OrderKey
      AND   ORDERS.[status] < '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63324
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On PickDetail. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END
END

IF UPDATE(TrafficCop)
BEGIN
    --NJOW03
   IF EXISTS (SELECT 1 FROM INSERTED i
              JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey
              JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue
              WHERE  s.configkey = 'OrdersTrigger_SP' AND i.TrafficCop IS NULL)
   BEGIN
       SELECT @c_TrafficCopAllowTriggerSP = 'Y'
   END

   --NJOW04
   IF EXISTS (SELECT 1 FROM INSERTED i
              JOIN storerconfig s WITH (NOLOCK) ON  i.storerkey = s.storerkey
              WHERE  s.configkey = 'SetSOStatusWhileStatusChange' AND i.TrafficCop IS NULL
              AND s.svalue = '1')
   BEGIN
      SELECT @c_TrafficCopAllowSOStatusUpd = 'Y'
   END

   --(Wan06) - START
   IF UPDATE(SOStatus)
   BEGIN
      IF EXISTS (SELECT 1 FROM INSERTED i WHERE  i.TrafficCop IS NULL)
      BEGIN
         SET @c_TrafficCopAllowEPACKStatusUpd = 'Y'
      END
   END
   --(Wan06) - END

   --WL03 S
   IF EXISTS (SELECT 1 FROM INSERTED I
              JOIN StorerConfig S WITH (NOLOCK) ON I.Storerkey = S.Storerkey
              WHERE S.Configkey = 'TrafficCopAllowITFTriggerCfg' AND I.TrafficCop IS NULL
              AND S.SValue = '1')
   BEGIN
       SELECT @c_TrafficCopAllowITFTriggerCfg = 'Y'
   END
   --WL03 E

   SELECT @n_continue = '4'
END

-- (james01)
IF @n_continue=1 or @n_continue=2
BEGIN
   IF UPDATE(SOSTATUS)
   BEGIN
--    IF EXISTS (SELECT 1 FROM ORDERS ORDERS WITH (NOLOCK)
--               JOIN INSERTED INSERTED ON ORDERS.OrderKey = INSERTED.OrderKey
--               WHERE ORDERS.SOSTATUS IN ('9', 'CANC'))
      IF EXISTS (
               SELECT 1
               FROM   INSERTED, DELETED
               WHERE  INSERTED.Orderkey = DELETED.Orderkey
               AND    INSERTED.SOSTATUS <> DELETED.SOSTATUS
 AND    DELETED.SOSTATUS IN ('9', 'CANC'))
    BEGIN
     SELECT @n_continue=3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                   + ': Update SO Extern Status Failed (ntrOrderHeaderUpdate). Orders is either Shipped or Cancelled. ( '
                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
    END
   END
END


-- (TLTING13)
IF @n_continue=1 or @n_continue=2
BEGIN
  IF EXISTS ( SELECT 1 FROM INSERTED, DELETED
        WHERE INSERTED.OrderKey = DELETED.OrderKey
               AND INSERTED.[status] = DELETED.[status]
               AND INSERTED.[status] = '9'  )
   BEGIN
      SELECT @n_continue = '4'
   END
END

-- Validation Script here
IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE @c_billing NVARCHAR(30)
   SELECT @c_billing = dbo.fnc_LTrim(dbo.fnc_RTrim(NSQLValue))
   FROM NSQLConfig WITH (NOLOCK)
   WHERE ConfigKey = 'WAREHOUSEBILLING'

   IF (@n_continue = 1 OR @n_continue=2 ) AND @c_billing = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM INSERTED WHERE ContainerQty < BilledContainerQty )
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62901   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                          + ': Container Qty can not be reduced. (ntrOrderHeaderUpdate)'
      END
   END
END

IF @n_continue=1 or @n_continue=2
BEGIN
   --(Wan02) - START
   SET @b_CustomSOCanc = 0
   SELECT @b_CustomSOCanc = 1
   FROM STORERCONFIG WITH (NOLOCK)
   JOIN INSERTED ON (STORERCONFIG.Storerkey = INSERTED.Storerkey)
               AND(STORERCONFIG.Facility = INSERTED.Facility OR ISNULL(RTRIM(STORERCONFIG.Facility),'') = '')
   WHERE STORERCONFIG.Configkey = 'ValidateSOStatus_SP'
   AND   STORERCONFIG.SValue = 'ispVSOST01'
   AND DocType <> 'E' --NJOW07
   --(Wan02) - END
   IF UPDATE(SOSTATUS)
   BEGIN
      --(Wan02) - START
      IF @b_CustomSOCanc = 1
      BEGIN
        SET @cTransFlag = '0'
        IF EXISTS(SELECT 1 FROM INSERTED WHERE INSERTED.Status IN ('1', '2', '3', '5'))
        BEGIN
          SET @cTransFlag = '1'
        END

        UPDATE ORDERS
        SET Type       = 'NIF'
           ,Trafficcop = NULL
           ,EditDate   = GETDATE()
           ,EditWho    = SUSER_NAME()
         FROM INSERTED
         JOIN ORDERS ON (ORDERS.Orderkey = INSERTED.Orderkey)
         WHERE INSERTED.Status IN ('3', '5')
           AND INSERTED.SOSTATUS = 'CANC'  -- Chee01

      SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
          SET @n_continue = 3
            SET @n_err      = 63116
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ORDERS. (ntrOrderHeaderUpdate)' + ' ( '
                       + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
--         END

         -- Chee01
--         IF @c_Status IN ('1', '2', '3', '5') AND (@n_Continue = 1 OR @n_Continue = 2)
         IF @cTransFlag = '1'
         BEGIN
            SET @n_Continue = 4
         END
      END

      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
      --(Wan02) - END
         IF EXISTS (SELECT 1 from INSERTED
                             JOIN DELETED ON INSERTED.OrderKey = DELETED.OrderKey
                             JOIN PICKDETAIL WITH (NOLOCK) on INSERTED.OrderKey = PICKDETAIL.Orderkey --ang01
                             WHERE DELETED.STATUS > '0'
                             AND   INSERTED.SOSTATUS = 'CANC')
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Cannot CANCEL Orders in Process (ntrOrderHeaderUpdate).'
         END
     -- Remarked on 21-Nov-2005 (SOS42858) -Start
     -- Linkage is not correct where @c_Orderkey is not pass-in value
        -- Start : SOS34759
       -- ELSE
  -- BEGIN
       --  IF EXISTS (SELECT 1 from INSERTED
       --                     WHERE INSERTED.SOSTATUS = 'CANC')
       --   BEGIN
       --     IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE Orderkey = @c_Orderkey)
       --      BEGIN
       --    SELECT @n_continue = 3
       --         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62502  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       --         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot CANCEL Orders if it is already Processed (ntrOrderHeaderUpdate).'
       --      END
       --   END
       -- END
       -- -- End : SOS34759
         ELSE
         BEGIN
            IF EXISTS (SELECT 1 FROM INSERTED
                       JOIN DELETED ON INSERTED.OrderKey = DELETED.OrderKey
                       JOIN PICKDETAIL WITH (NOLOCK) ON INSERTED.OrderKey = PICKDETAIL.OrderKey AND Qty > 0 -- (Shong01)
                       WHERE INSERTED.SOSTATUS = 'CANC')
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62903  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Cannot CANCEL Orders if it exists in PickDetail (ntrOrderHeaderUpdate).'
            END

            -- tlting03
            IF EXISTS (SELECT 1 FROM INSERTED
                       JOIN DELETED ON INSERTED.OrderKey = DELETED.OrderKey
                       JOIN PreAllocatePickDetail WITH (NOLOCK) ON INSERTED.OrderKey = PreAllocatePickDetail.OrderKey
                       WHERE INSERTED.SOSTATUS = 'CANC' )

            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62903  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Cannot CANCEL Orders if it exists in PreAllocatePickDetail (ntrOrderHeaderUpdate).'

            END
            -- SOS42858 -End
         END--(Wan02)
      END
 END
END


-- TLTING11 START
IF (@n_Continue = 1 OR @n_Continue = 2) AND UPDATE(shipperkey)
BEGIN
   IF EXISTS (SELECT 1 FROM INSERTED
               JOIN DELETED ON INSERTED.OrderKey = DELETED.OrderKey
               WHERE INSERTED.shipperkey <> DELETED.shipperkey AND INSERTED.doctype = 'E'
               AND INSERTED.status < '9')

   BEGIN

      SELECT Orders.Orderkey, Trackingno = ISNULL( RTRIM(Orders.Trackingno), Orders.Userdefine04)
      INTO #OrdTrackingNO
      FROM Orders with (NOLOCK)
         JOIN INSERTED ON INSERTED.OrderKey = Orders.OrderKey
         JOIN DELETED ON INSERTED.OrderKey = DELETED.OrderKey
      WHERE INSERTED.shipperkey <> DELETED.shipperkey
         AND Orders.Doctype = 'E'
         AND Orders.Status < '9'

       Delete #OrdTrackingNO where Trackingno = '' or Trackingno is NULL

       DECLARE OrdTrackingno CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
    SELECT Trackingno
      FROM #OrdTrackingNO

      OPEN OrdTrackingno

      FETCH NEXT FROM OrdTrackingno INTO @c_Trackingno

      WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN

         Delete from Cartontrack Where TrackingNo = @c_Trackingno
         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62933  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                              + ': Fail to Clear Cartontrack . (ntrOrderHeaderUpdate).'

         END
         FETCH NEXT FROM OrdTrackingno INTO @c_Trackingno
      END
      CLOSE OrdTrackingno
  DEALLOCATE OrdTrackingno

      UPDATE Orders
      Set Userdefine04 = '',
         Trackingno = '',
         Editdate =getdate(),
         Editwho = Suser_Sname(),
         TrafficCop = NULL
      FROM Orders
         JOIN #OrdTrackingNO I ON I.OrderKey = Orders.OrderKey
      WHERE   Orders.Doctype = 'E'
         AND Orders.Status < '9'

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62934  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                           + ': Fail to Update to Clear TrackingNo . (ntrOrderHeaderUpdate).'
      END
   END
END
--END TLTING11

--NJOW01 Start
IF (@n_Continue = 1 OR @n_Continue = 2) AND UPDATE(SOStatus)
BEGIN
   DECLARE CANCORDCUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT INSERTED.OrderKey
   FROM INSERTED
   JOIN DELETED ON INSERTED.Orderkey = DELETED.Orderkey
   WHERE INSERTED.SOStatus = 'CANC'
   AND INSERTED.SOStatus <> DELETED.SOStatus

   OPEN CANCORDCUR

   FETCH NEXT FROM CANCORDCUR INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      EXECUTE dbo.isp_OrderCancel_Wrapper
           @c_Orderkey
         , @b_Success  OUTPUT
         , @n_Err      OUTPUT
         , @c_ErrMsg   OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 62803   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                          + ': Order Cancellation Failed (ntrOrderHeaderUpdate) ( '
                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END

      FETCH NEXT FROM CANCORDCUR INTO @c_Orderkey
   END
   CLOSE CANCORDCUR
   DEALLOCATE CANCORDCUR
END
--NJOW01 End


-- Interface and Updating Script here
IF (@n_continue = 1 OR @n_continue = 2 OR (@c_TrafficCopAllowSOStatusUpd = 'Y' AND @n_continue <> 3))
BEGIN
   SELECT @c_Orderkey = ''
   SELECT @c_PrevFacility = ''
   SELECT @c_PrevStorerKey = ''

   DECLARE ORDCUR CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT OrderKey
   FROM   INSERTED
   ORDER BY StorerKey, Facility, ConsigneeKey

   OPEN ORDCUR
   FETCH NEXT FROM ORDCUR INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1  AND (@n_continue = 1 OR @n_continue = 2 OR (@c_TrafficCopAllowSOStatusUpd = 'Y' AND @n_continue <> 3))
   BEGIN
      SELECT @c_Facility    = INSERTED.Facility,
             @c_StorerKey   = INSERTED.Storerkey,
             @c_PreSOStatus = DELETED.SOStatus,
             @c_CurSOStatus = INSERTED.SOStatus,
             @n_OpenQty     = INSERTED.OpenQty,
             @c_Status      = INSERTED.Status,
             @c_PrevStatus  = DELETED.Status,
             @c_OrdType     = INSERTED.Type,
             @c_ContainerType = ISNULL(RTRIM(INSERTED.ContainerType), ''),
             @n_ContainerQty  = INSERTED.ContainerQty,
             @n_BilledContainerQty = INSERTED.BilledContainerQty,
             @c_UserDefine08  = INSERTED.UserDefine08,
             @c_ExternOrderKey = INSERTED.ExternOrderKey,
             @c_Issued = INSERTED.Issued,     -- SOS22457
             @c_SOStatus = INSERTED.SoStatus, -- SOS22457
             @c_RoutingTool = INSERTED.RoutingTool, -- SOS53821
             @c_OldRoutingTool = DELETED.RoutingTool,
             @c_Route = INSERTED.Route,  -- SOS80697
             @c_Consigneekey = INSERTED.Consigneekey,  -- (YokeBeen03)
             @c_PrevExternOrderKey = DELETED.ExternOrderKey,  -- (ChewKP01)
             @c_Specialhandling = INSERTED.Specialhandling,   -- (MC02)
             @c_OrdStatus = INSERTED.Status,
             @c_DocType   = INSERTED.DocType,
             @c_ECOM_PRESALE_FLAG  = INSERTED.ECOM_PRESALE_FLAG, --NJOW05
             @c_ECOM_Platform = INSERTED.ECOM_Platform   --WL02
      FROM   INSERTED, DELETED
      WHERE  INSERTED.Orderkey = DELETED.OrderKey
      AND    INSERTED.Orderkey = @c_Orderkey       -- tlting04

      --IF @c_NSQLValue = '1' AND @c_ExternOrderKey <> @c_PrevExternOrderKey
      --BEGIN
      --   SET @d_step1 = GETDATE() - @d_step1 -- (tlting01)
      --   SET @c_Col1 = 'PrevExternOrderKey'
      --   SET @c_Col2 = @c_PrevExternOrderKey
      --   SET @c_Col3 = 'ExternOrderKey'
      --   SET @c_Col4 = @c_ExternOrderKey

      --   SET @d_step2 = GETDATE()  -- (tlting01)

      --    SET @d_endtime = GETDATE()
      --    INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,
      --                           Step1, Step2, Step3, Step4, Step5,
      --                           Col1, Col2, Col3, Col4, Col5)
      --    VALUES
      --       (RTRIM(@c_TraceName), @d_starttime, @d_endtime
      --       ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
      --       ,CONVERT(CHAR(12),@d_step1,114)
      --       ,CONVERT(CHAR(12),@d_step2,114)
      --       ,CONVERT(CHAR(12),@d_step3,114)
      --     ,CONVERT(CHAR(12),@d_step4,114)
      --       ,CONVERT(CHAR(12),@d_step5,114)
      --       ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

      --       SET @d_step1 = NULL
      --       SET @d_step2 = NULL
      --       SET @d_step3 = NULL
      --       SET @d_step4 = NULL
      --       SET @d_step5 = NULL

      -- END

      IF (@c_Facility <> @c_PrevFacility) OR (@c_StorerKey <> @c_PrevStorerKey) OR (@c_PreConsigneekey <> @c_Consigneekey)
      BEGIN

         SELECT @c_PrevFacility = @c_Facility,
                @c_PrevStorerKey = @c_StorerKey

         SET @c_PreConsigneekey = @c_Consigneekey

         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'SHIPLOG',      -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority        OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SHIPLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            EXECUTE dbo.nspGetRight NULL,
                     @c_StorerKey,   -- Storer
                     '',                   -- Sku
                     'PMTLPICK',           -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority_pmtl   OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            END

            EXECUTE dbo.nspGetRight NULL,
                     @c_StorerKey,   -- Storer
                     '',        -- Sku
                     'OWITF',          -- ConfigKey
                     @b_success         OUTPUT,
                     @c_authority_owitf OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (OWITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            -- Added By SHong on 18-Aug-2003
            -- Fuji Interface
            SELECT @b_success = 0

             EXECUTE dbo.nspGetRight  '',
                     @c_StorerKey,   -- Storer
                     '',                   -- Sku
                           'FUJIMYITF',         -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_fujiitf  OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62906   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (FUJIMYITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,        -- Storer
                     '',                     -- Sku
                     'PICK-TRF',          -- ConfigKey
                     @b_success  OUTPUT,
                     @c_authority_pkitf OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICK-TRF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            EXECUTE dbo.nspGetRight
                              @c_Facility,  --NJOW06
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'DSCPICK',           -- ConfigKey
                     @b_success           OUTPUT,
                     @c_authority_dscpick OUTPUT,
                     @n_err               OUTPUT,
                     @c_errmsg            OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62908   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (DSCPICK) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            --(Wan01) - START
            EXECUTE dbo.nspGetRight
                    ''                  -- Facility
                  , @c_StorerKey        -- Storer
                  , ''                  -- Sku
                  , 'KITDSCPICK'        -- ConfigKey
                  , @b_success           OUTPUT
                  , @c_KitDSCPick        OUTPUT
                  , @n_err               OUTPUT
                  , @c_errmsg            OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
               SET @n_err=62908   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Retrieve of Right (KITDISPICK) Failed (ntrOrderHeaderUpdate) ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            --(Wan01) - END

            -- added by Jeff 05 April 2004 - MANDOM Pick Confirmation Export
            sELECT @b_success = 0

            EXECUTE dbo.nspGetRight  @c_facility,
                     @c_StorerKey,  -- Storer
                     '',                  -- Sku
                     'MANDOMMYITF',          -- ConfigKey
                    @b_success            OUTPUT,
                     @c_authority_mandommy OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62909   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (MANDOMMYITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            -- end - jeff 05 april 2004

            -- NZMM ShipConfirm Export (SOS8999) -Start(2)
            -- Get sValue from StorerConfig table, only equals to '1' then proceed
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  @c_facility,
                     @c_StorerKey,  -- Storer
                     '',                  -- Sku
                     'NZMMITF',           -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_nzmmitf  OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (NZMMITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
        -- NZMM ShipConfirm Export (SOS8999) -End(2)

            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'NWInterface',          -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_nwitf     OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg      OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62911   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (NWInterface) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            -- Added By SHONG on 18-Mar-2004
            -- For NIKE REG Cancel or Stop Order
            EXECUTE dbo.nspGetRight  @c_facility,
                     @c_StorerKey,  -- Storer
                     '',                  -- Sku
                     'NIKEREGITF',           -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_nkreg    OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62912   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (NIKEREGITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'LOREALITF',         -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_lorealitf OUTPUT,
                           @n_err                 OUTPUT,
                     @c_errmsg              OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62913   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (LOREALITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            -- SOS# 21780
            -- Interface for Cancelled Orders
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,      -- Storer
                     '',                  -- Sku
                     'ULPITF',       -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_ulpitf    OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg          OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62914   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (ULPITF) Failed (ntrOrderHeaderUpdate) ( '
   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            -- Taiwan Unilever Interface
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'UTLITF',         -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_utlitf    OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg              OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62915   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (UTLITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END

            -- SOS22726
            -- Interface for SG Ciba Vision Despatch Confirmation
            DECLARE @c_authority_cibaitf NVARCHAR(1)
            SELECT @b_success = 0

 EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'CIBAITF',           -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_cibaitf   OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg              OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62916   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (CIBAITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
      END -- SOS# 22726

            -- Added by RickyYee on 19-Oct-2004 (Carrefour Gold Interface - start)
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'C4ITF',   -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_c4itf     OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg              OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62917   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (C4ITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            -- Added by RickyYee on 19-Oct-2004 (Carrefour Gold Interface - End)

            -- SOS32009 PickConfirm Interface -Start(2)
            SELECT @b_success = 0

  EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'PICKCFMITF',        -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_pickcfmitf OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62918   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICKCFMITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            -- SOS32009 PickConfirm Interface -End(2)

            -- SOS30121 MAXXIUM Pick Confirm & SOS30126 MAXXIUM Shipment Order Confirm
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
    '',                  -- Sku
                     'MSFITF',            -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_msfitf     OUTPUT,
                     @n_err      OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62919   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (MSFITF) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            -- End of SOS30121 & SOS30126

            -- Generic Ship Confirm Export
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'SOCFMLOG',     -- ConfigKey
                     @b_success          OUTPUT,
               @c_authority_socfm  OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SOCFMLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            -- (MC03) - S
            -- Generic Alternate Ship Confirm Export
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'SOCFM2LOG',    -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority_socfm2 OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
         BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SOCFM2LOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC03) - E

            -- (MC04) - S
            -- Generic Alternate Ship Confirm Export
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'LORADV',       -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority_LorAdv OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (LORADV) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC04) - E

            -- (MC05) - S
           EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'VPACKLOG',     -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_VPackLog   OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (VPACKLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC05) - E
            -- (MC06) - S
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'PICKINMAIL',   -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_PickInMail OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICKINMAIL) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC06) - E

            -- (MC07) - S
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,  -- Storer
                     '',             -- Sku
                     'SOSHPCFMCMS',  -- ConfigKey
                     @b_success               OUTPUT,
                     @c_authority_SOShpCfmCMS OUTPUT,
                     @n_err               OUTPUT,
                     @c_errmsg                OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SOSHPCFMCMS) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC07) - E
            -- (MC08) - S
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
   '',             -- Sku
                     'REINSTTL3',    -- ConfigKey
                     @b_success               OUTPUT,
                     @c_authority_REInstTL3   OUTPUT,
                     @n_err                   OUTPUT,
                     @c_errmsg                OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (REINSTTL3) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC08) - E

            -- Added by MaryVong on 08-Mar-2007
            -- Generic Cancelled Order Interface
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'CANCSOLOG',    -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority_cancso OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg      OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (CANCSOLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            -- (KT01) - Start
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,         -- Storer
                     '',
                     'WSCRSOCANC',         -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_crcancso OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                            + ': Retrieve of Right (WSCRSOCANC) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,         -- Storer
                     '',
                     'WSCRSOCFM',         -- ConfigKey
                     @b_success            OUTPUT,
                     @c_authority_crshpcfm OUTPUT,
                     @n_err                OUTPUT,
                     @c_errmsg             OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (WSCRSOCFM) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

        EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,         -- Storer
                     '',
                     'WSCRSOCFM2',         -- ConfigKey
                     @b_success             OUTPUT,
                     @c_authority_crshpcfm2 OUTPUT,
                     @n_err                 OUTPUT,
                     @c_errmsg              OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (WSCRSOCFM) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (KT01) - End

            -- (MC01) - Start
      -- Generic CMS Cancelled Order Interface
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,           -- Storer
                     '',                     -- Sku
                     'SOCANCCMS',            -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_canccmsso  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SOCANCCMS) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC01) - End

            -- (MC02) - Start
            -- Generic 3PL Order Interface
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,           -- Storer
                     '',                     -- Sku
                     'SO3PLLOG',             -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_so3pl      OUTPUT,
                     @n_err                  OUTPUT,
@c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (SO3PLLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
            -- (MC02) - End

            --    Added by MaryVong on 04-Jun-2008
            --    FBR107528 POS Interface
            EXECUTE dbo.nspGetRight @c_Facility,
                     @c_StorerKey,   -- Storer
                     '',             -- Sku
                     'POSITF',      -- ConfigKey
                     @b_success          OUTPUT,
                     @c_authority_positf OUTPUT,
                     @n_err              OUTPUT,
                     @c_errmsg           OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62922   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                + ': Retrieve of Right (POSITF) Failed (ntrOrderHeaderUpdate) ( '
            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            SET @c_authority_tms = '0'

            SELECT @c_authority_tms = ISNULL(sValue, '0')
            FROM StorerConfig WITH (NOLOCK)
            WHERE StorerConfig.StorerKey = @c_StorerKey
              AND ConfigKey IN ('TMSOutOrdHDR','TMSOutOrdDTL')

            -- (YokeBeen01) Start
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  NULL,
                    @c_StorerKey,        -- Storer
                    '',                  -- Sku
                    'PICKINPROG',        -- ConfigKey
                    @b_success              OUTPUT,
                    @c_authority_pickinprog OUTPUT,
                    @n_err                  OUTPUT,
                    @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62923
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICKINPROG) Failed (ntrOrderHeaderUpdate)'
             + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
               BREAK
            END
            -- (YokeBeen01) End

            -- Added by MCTANG on 31-Jul-2008 (SOS#110280 Vital WMS Ship Confirm) - Start
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  NULL,
                    @c_StorerKey,        -- Storer
                    '',                  -- Sku
                    'VSHPLOG',           -- ConfigKey
                    @b_success              OUTPUT,
                    @c_authority_vshplog    OUTPUT,
                    @n_err                  OUTPUT,
                    @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63923
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (VSHPLOG) Failed (ntrOrderHeaderUpdate)'
                                + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
               BREAK
            END
            -- Added by MCTANG on 31-Jul-2008 (SOS#110280 Vital WMS Ship Confirm) - End

            -- (YokeBeen02) Start
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  NULL,
                    @c_StorerKey,        -- Storer
                    '',                  -- Sku
                    'PREINVLOG',         -- ConfigKey
                  @b_success              OUTPUT,
                    @c_authority_preinvitf  OUTPUT,
                    @n_err                  OUTPUT,
                    @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62923
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PREINVLOG) Failed (ntrOrderHeaderUpdate)'
                                + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
               BREAK
            END
            -- (YokeBeen02) End

            -- (YokeBeen03) Start
            SELECT @b_success = 0
            EXECUTE dbo.nspGetRight  NULL,
                    @c_StorerKey,        -- Storer
                    '',                  -- Sku
                    'SOCFMWOW',          -- ConfigKey
                    @b_success              OUTPUT,
                    @c_authority_socfmwow   OUTPUT,
                    @n_err                  OUTPUT,
                    @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @b_success = 0
               EXECUTE dbo.nspGetRight  NULL,
                       @c_Consigneekey,     -- Storer
                       '',  -- Sku
                       'SOCFMWOW',          -- ConfigKey
                       @b_success              OUTPUT,
                       @c_authority_socfmwow   OUTPUT,
                       @n_err                  OUTPUT,
                       @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62923
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (SOCFMWOW) Failed (ntrOrderHeaderUpdate)'
                                   + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '
                  BREAK
               END -- By @c_Consigneekey
            END -- By @c_StorerKey
            -- (YokeBeen03) End

            -- Added By Vicky on 11 Oct 2005
            -- Generic PickConfirm Interface -Start
            SELECT @b_success = 0

            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'PICKCFMLOG',        -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_pickcfmlog OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62924   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICKCFMLOG) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
            -- Generic PickConfirm Interface -End

            SELECT @b_success = 0

            SET @c_authority_XFieldEdit = ''
            EXECUTE dbo.nspGetRight  NULL,
                     @c_StorerKey,        -- Storer
                     '',                  -- Sku
                     'XFieldEdit',        -- ConfigKey
                     @b_success              OUTPUT,
                     @c_authority_XFieldEdit OUTPUT,
                     @n_err                  OUTPUT,
    @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62924   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (FeildEditX) Failed (ntrOrderHeaderUpdate) ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               BREAK
            END
         END

         -- Shong002
         SET @c_SetSOStatusWhileStatusChange = dbo.fnc_GetRight(@c_Facility, @c_StorerKey, '', 'SetSOStatusWhileStatusChange')
      END -- if diff storerkey or diff facility or

      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXECUTE     dbo.ispGetOrderStatus
                        @c_OrderKey
         ,              @c_StorerKey
         ,      @c_OrdType
         ,              @c_Status    OUTPUT
         ,              @b_Success   OUTPUT
         ,              @n_err       OUTPUT
         ,              @c_errmsg    OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         End
      END -- Set Header Status

      -- SHONG002
       -- tlting07 bug fix
      IF (@n_continue = 1 OR @n_continue = 2 OR (@c_TrafficCopAllowSOStatusUpd = 'Y' AND @n_continue <> 3)) AND @c_SetSOStatusWhileStatusChange = '1' AND ( @c_CurSOStatus = '0' ) -- AND @c_Status = '5') --NJOW04
      BEGIN
         SET @c_NewSOStatus = ''

         SELECT TOP 1 @c_NewSOStatus = c.Short
         FROM   CODELKUP AS c WITH (NOLOCK)
         WHERE  c.LISTNAME = 'ORDSTSMAP'
         AND    c.Code      = @c_Status
         AND    c.Storerkey = @c_Storerkey
         AND    c.UDF01     = @c_DocType
         AND   (ISNULL(c.UDF02, '') = '' OR c.UDF02 = @c_ECOM_PRESALE_FLAG)  --NJOW05
         AND   (ISNULL(c.UDF03, '') = '' OR c.UDF03 = @c_ECOM_Platform)  --WL02
         ORDER BY c.UDF02 DESC, c.UDF03 DESC   --NJOW03   --WL02

         IF @c_NewSOStatus IS NULL
            SET @c_NewSOStatus = ''

         IF @c_TrafficCopAllowSOStatusUpd = 'Y' --NJOW04
         BEGIN
             UPDATE ORDERS
             SET Editdate = getdate(),
                 Editwho = SUSER_SNAME(),
                 SOStatus = CASE WHEN @c_SetSOStatusWhileStatusChange = '1' AND @c_NewSOStatus <> '' THEN
                                      @c_NewSOStatus
                            ELSE SOStatus
                            END, -- Shong002
                 Trafficcop = NULL
            FROM ORDERS
          JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
            WHERE OrderKey = @c_OrderKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Update Failed On ORDERS. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
      END

      -- Check Column Changed
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority_XFieldEdit = '1'
      BEGIN
         IF Exists ( Select 1 from Codelkup (NOLOCK) where LISTNAME = 'XFieldEdit' AND Storerkey = @c_StorerKey
                     AND Code = 'DeliveryDate' )
         BEGIN
            IF EXISTS ( Select 1 from Codelkup (NOLOCK) where LISTNAME = 'XEditRule1' AND Storerkey = @c_StorerKey  )
            BEGIN
               IF Exists ( SELECT 1 FROM INSERTED I
                          JOIN DELETED D ON D.OrderKey = I.OrderKey
                          JOIN Codelkup C WITH (NOLOCK) ON C.LISTNAME = 'XEditRule1' AND C.Storerkey = I.StorerKey
                                       AND C.Code = I.consigneekey
                          WHERE D.DeliveryDate <> I.DeliveryDate )
                BEGIN
                             SELECT @n_continue=3
                             SELECT @n_err=66115
                             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                             SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                           + ': Update DeliveryDate not allow! (ntrOrderHeaderUpdate). ( '
                                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            ELSE
            BEGIN
               IF Exists ( SELECT 1 FROM INSERTED I
                          JOIN DELETED D ON D.OrderKey = I.OrderKey
                          WHERE D.DeliveryDate <> I.DeliveryDate )
               BEGIN
                             SELECT @n_continue=3
                             SELECT @n_err=66116
                             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err)   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                             SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                           + ': Update DeliveryDate not allow! (ntrOrderHeaderUpdate). ( '
                                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
         END
      END

      -- Overwrite Orders Status
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         -- Modify by SHONG 24-Mar-2994 for NSC Project
         IF (@c_CurSOStatus = '9' OR @c_CurSOStatus IN ('CANC', 'SHORTSHIP')) AND
            -- @c_PrevSTATUS = '0' Change by SHONG on 25th Sept 2012 (SOS# 256343)
            ( @c_PrevSTATUS = '0' OR (( @c_PrevSTATUS = 'CANC' OR @c_CurSOStatus ='CANC') AND @c_Status = '0')) --ang01
         BEGIN
            -- Modify by SHONG 24-Mar-2994 for NSC Project
            IF @c_CurSOStatus = 'CANC'
            BEGIN
               --WL01 START
               IF @b_CustomSOCanc = 1
               BEGIN
                  IF EXISTS (SELECT * FROM dbo.sysobjects WHERE  id = OBJECT_ID(N'[dbo].[ispVSOST01]') AND OBJECTPROPERTY(id ,N'IsProcedure') = 1 )
                  BEGIN
                     EXEC ispVSOST01
                       @c_OrderKey = @c_OrderKey
                     , @b_success  = @b_success OUTPUT
                     , @n_err      = @n_err     OUTPUT
                     , @c_errmsg   = @c_errmsg  OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                         + ': Error Executing ispVSOST01 (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                         + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                     END
                     ELSE IF @b_success = 1
                     BEGIN
                        SELECT @c_Status = 'CANC'
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                    + ':  ispVSOST01 Not Found. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE=' + RTrim(@c_errmsg) + ' ) '
                  END
               END

               --WL01 END

               --(Wan02) - START
               IF NOT (@b_CustomSOCanc = 1
                  AND  EXISTS ( SELECT 1
                                FROM WAVEDETAIL WITH (NOLOCK)
                                WHERE Orderkey = @c_Orderkey ) )

               BEGIN
               --(Wan02) - END
                  SELECT @c_Status = 'CANC'
               END   --(Wan02)
            END
            ELSE
            BEGIN
               SELECT @c_Status = '9'
            END

            --2024-09-09 - START
            IF @n_Continue IN (1,2)
            BEGIN
               IF EXISTS(SELECT 1 FROM INSERTED
                          JOIN StorerSODefault sod (NOLOCK) ON sod.Storerkey = INSERTED.Storerkey
                          JOIN ORDERS oh (NOLOCK) ON  oh.Orderkey = INSERTED.ORderkey
                          WHERE INSERTED.[Status] = 'CANC'
                          AND INSERTED.CancelReasonCode = ''
                          AND sod.ReasonCodeReqForSOCancel = 'Yes'
                        )
               BEGIN
                  SET @n_continue = 3
                  SET @n_err = 63117
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cancel ReasonCode is required. (ntrOrderDetailUpdate)'
               END
            END

            IF @n_Continue IN (1,2)                                                 --2024-09-09
            BEGIN                                                                   --2024-09-09
               -- tlting04
               -- Update Orderdetail status as per order.status
               IF(@c_Status='CANC')
                  BEGIN
                     UPDATE ORDERDETAIL
                     SET EditDate   = GETDATE(),
                         EditWho    = Suser_sname(),
                         Status     = @c_Status
                     WHERE OrderKey = @c_OrderKey
                  END
               ELSE
                  BEGIN
                     UPDATE ORDERDETAIL
                     SET Trafficcop = NULL,
                         EditDate   = GETDATE(),
                         EditWho    = Suser_sname(),
                         Status     = @c_Status     -- '9'
                     WHERE OrderKey = @c_OrderKey
                  END

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63115   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                 + ': Update OrderDetail Failed. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                   + RTrim(@c_errmsg) + ' ) '
               END
            END                                                                     --2024-09-09
         END
      END

      --(wan01) - START
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_KitDSCPick > '0'
         BEGIN
            IF EXISTS ( SELECT 1 FROM CODELKUP WITH (NOLOCK) WHERE LISTNAME = 'KIT2SO' AND CODE = @c_Storerkey AND Short = @c_Ordtype ) AND
               EXISTS ( SELECT 1 FROM ORDERS WITH (NOLOCK) JOIN KIT WITH (NOLOCK) ON (ORDERs.ExternOrderkey = KIT.KitKey)
                        WHERE ORDERS.Orderkey = @c_Orderkey AND ORDERS.Ordergroup = 'KIT' )
            BEGIN
               IF @c_KitDSCPick = '1'
               BEGIN
                  SET @c_UserDefine08 = 'Y'
               END
         ELSE IF @c_KitDSCPick = '2'
               BEGIN
   SET @c_UserDefine08 = 'N'
               END
            END
         END
         ELSE
         BEGIN
         --(wan01) - END
            IF @c_authority_dscpick = '1'
            BEGIN
               IF @c_UserDefine08 = 'N'
                  SELECT @c_UserDefine08 = 'Y'
            END
         END   --(wan01)
      END

      -- (SOS53821) Start (Shong001)
      IF (@n_continue = 1 OR @n_continue = 2) AND
          @c_authority_tms = '1' AND
          @c_RoutingTool = 'Y' AND
          @c_OldRoutingTool <> 'Y'
      BEGIN
         SET @c_Tablename = ''

         SELECT @c_Tablename = ConfigKey
           FROM StorerConfig WITH (NOLOCK)
          WHERE StorerConfig.StorerKey = @c_StorerKey
            AND ConfigKey IN ('TMSOutOrdHDR','TMSOutOrdDTL')
            AND sValue = '1'

         IF @c_Tablename IN ('TMSOutOrdHDR','TMSOutOrdDTL')
         BEGIN
            EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, '', @c_StorerKey, ''
                , @b_success OUTPUT
                , @n_err OUTPUT
                , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Insert into TMSLog Failed (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END
      END
      -- (SOS53821) End (Shong001)

      -- SOS80697 Start
      DECLARE @c_InsertTMSIfModified NVARCHAR(1)
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @c_InsertTMSIfModified = ''

         SELECT @c_InsertTMSIfModified = ISNULL(sValue, '0')
         FROM StorerConfig WITH (NOLOCK)
         WHERE StorerConfig.StorerKey = @c_StorerKey
         AND ConfigKey = 'InsertTMSIfModified'

         IF @c_InsertTMSIfModified = '1'
         BEGIN
            SET @c_Tablename = ''

            SELECT @c_Tablename = ConfigKey
              FROM StorerConfig WITH (NOLOCK)
             WHERE StorerConfig.StorerKey = @c_StorerKey
               AND ConfigKey IN ('TMSOutOrdHDR','TMSOutOrdDTL')
               AND sValue = '1'

            IF EXISTS (SELECT 1 FROM INSERTED
               WHERE Inserted.LoadKey = '') AND @c_Tablename IN ('TMSOutOrdHDR','TMSOutOrdDTL')

--            IF @c_Tablename IN ('TMSOutOrdHDR','TMSOutOrdDTL')
            BEGIN
             -- Insert records into TMSLog table
               -- SOS80697 if orders.deliverydate or orders.rdd is changed/updated, set Key2 = 'M'
               IF UPDATE(DeliveryDate) OR UPDATE(Rdd)
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM TMSLog WITH (NOLOCK) WHERE TableName = @c_TableName
                     AND Key1 = @c_OrderKey AND Key2 = 'M' AND Key3 = @c_StorerKey)
                  BEGIN
                   EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, 'M', @c_StorerKey, ''
                      , @b_success OUTPUT
                      , @n_err OUTPUT
                      , @c_errmsg OUTPUT
                  END
               ELSE
                  BEGIN
 UPDATE TMSLOG
                        SET Transmitflag = '0',
                            EditDate = GETDATE() -- SWT99
                     WHERE TableName = @c_TableName
 AND Key1 = @c_OrderKey
                        AND Key2 = 'M'
                        AND Key3 = @c_StorerKey
                  END
               END
               ELSE
               BEGIN
                  IF NOT EXISTS ( SELECT 1 FROM TMSLog WITH (NOLOCK) WHERE TableName = @c_TableName
                     AND Key1 = @c_OrderKey AND Key2 = 'D' AND Key3 = @c_StorerKey)
                  BEGIN
                   -- if orders.route changed to '00CNX' or orders,status changed to 'CANC', set Key2 = 'D'
                   IF @c_Route = '00CNX' OR @c_Status = 'CANC'
                      EXEC ispGenTMSLog @c_Tablename, @c_OrderKey, 'D', @c_StorerKey, ''
                         , @b_success OUTPUT
                         , @n_err OUTPUT
                         , @c_errmsg OUTPUT
                  END
                  ELSE
                  BEGIN
                     UPDATE TMSLOG
                        SET Transmitflag = '0',
                            EditDate = GETDATE() -- SWT99
                      WHERE TableName = @c_TableName
                        AND Key1 = @c_OrderKey
                        AND Key2 = 'D'
                        AND Key3 = @c_StorerKey
                  END
               END
            END
         END
      END
  -- SOS80697 End

      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         -- Added By SHONG
         -- Taiwan Unilever Interface
         IF @c_authority_utlitf = '1' AND (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            IF @c_SOStatus = 'LOADPLAN'
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'UTLALORD', @c_OrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               End
            END
         END

         IF @c_Status = '5' OR @c_Status = 'CANC'
         BEGIN
            -- added by Jeff 05 April 2004 - Mandom pick confirmation
            IF @c_authority_mandommy = '1' AND @c_status = '5'
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'MDMMYPICK', @c_OrderKey, '', @c_Storerkey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               End
            END
            -- end -- jeff 05 april 2004

            -- Thailand PMTL Interface
            IF @c_authority_pmtl = '1'
            BEGIN
               EXEC dbo.ispGenTransmitLog 'PMTLPICK', @c_OrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                               , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               End
            END

        -- OW Interface OWORDPICK
            IF @c_authority_pkitf = '1' AND @c_authority_owitf = '1' AND @c_Status <> 'CANC'
            BEGIN
               EXEC dbo.ispGenTransmitLog 'OWORDPICK', @c_OrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
               IF @b_success <> 1
           BEGIN
                  SELECT @n_continue = 3
               End
            END

            -- Start - SOS22726 (CIBAITF Interface), Add by June 8.JUL.2004
            -- Added checking on 'CANC' as requested by CIBA users, by MaryVong on 31-May-2005
            -- SOS41481 Do not interface while Type = 'KITTING'
            IF @c_authority_cibaitf = '1' AND @c_OrdType <> 'KITTING' AND (@c_Status = '5' OR @c_Status = 'CANC')
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'CIBAPICKCFM', @c_OrderKey, '', '', ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
           IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               End
            END -- End - SOS22726

            -- SOS66030 - Change to ispGenTransmitLog3
            -- NZMM ShipConfirm Interface (SOS18999) -Start(3)
            IF @c_authority_nzmmitf = '1' AND @c_Status = '5'
            BEGIN
               -- When short='PICK', insert a record into TransmitLog2 table
               SELECT @c_NZShort = Short
               FROM CODELKUP WITH (NOLOCK)
               WHERE ListName = 'NZMMSOCFM'
               AND Code = @c_OrdType

               IF @c_NZShort = 'PICK'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'NZPICKCONF', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                        , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- @c_NZShort = 'PICK'
            END -- @c_authority_nzmmitf = '1' AND @c_Status = '5'
            --NZMM ShipConfirm Interface (SOS18999) -End(3)

            -- Added By SHONG SOS# 21961
            -- Modified by MaryVong on 09Sept04 (SOS26923)
            IF @c_authority_lorealitf = '1' AND (@c_Status = '5' OR @c_CurSOStatus = 'CANC')
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'LORLPICK', @c_OrderKey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- @c_authority_nzmmitf = '1' AND @c_Status = '5'
            -- Added by Shong on 13-APR-2004 SOS# 21961

            -- Start : SOS27424
            -- OW Interface for Cancelled Orders
            IF @c_authority_owitf = '1' AND (@c_Status = 'CANC' OR @c_CurSOStatus = 'CANC')
            BEGIN
               EXEC ispGenTransmitLog 'OWORDCANC', @c_OrderKey, '', '', ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT                                        , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END
            -- End : SOS27424

            -- SOS# 21780
            -- Interface for Cancelled Orders
            IF @c_authority_ulpitf = '1' AND @c_SOStatus = 'CANC' AND
               EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
                         JOIN CODELKUP WITH (NOLOCK) ON (ORDERS.Type = CODELKUP.Code)
                       WHERE CODELKUP.Listname = 'ORDERTYPE'
                       AND   CODELKUP.Short = '1')
            BEGIN
               IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
                          WHERE ExternOrderkey = @c_ExternOrderkey AND Orderkey <> @c_Orderkey
                          -- AND SOStatus <> 'CANC')
                          AND SOStatus NOT IN ('CANC', '9'))
                  SELECT @c_lastloadflag = 'N'
               ELSE
                  SELECT @c_lastloadflag = 'Y'

               EXEC dbo.ispGenTransmitLog 'ULPSOCANC', @c_OrderKey, @c_lastloadflag, @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END
            END -- End - SOS# 21780
         END -- IF @c_Status = '5' OR @c_Status = 'CANC'
      END -- continue = 1

      -- Insert into Interface Log table
      IF @c_authority = '1'  AND ( @n_OpenQty <= 0 OR @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog 'ORDERS', @c_OrderKey, '', '', ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         End
      END

      IF @c_authority_fujiitf = '1' AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_SOStatus = 'CANC'
            AND @n_OpenQty > 0
            AND ( dbo.fnc_RTrim(@c_Issued) IS NULL OR dbo.fnc_RTrim(@c_Issued) = '' )
            AND @c_ExternOrderKey NOT Like 'I%'
         BEGIN
            EXEC dbo.ispGenTransmitLog 'FUJIMYORD', @c_OrderKey, '', '', ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            End
         END
      END

      -- SOS32009 PickConfirm Interface -Start(3)
      IF @c_authority_pickcfmitf = '1' AND @c_Status = '5' AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog 'UNIPICK', @c_OrderKey, '', @c_StorerKey, ''
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- SOS32009 PickConfirm Interface -Start(3)

      -- (YokeBeen02) Start
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_preinvitf = '1'
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG3 WITH (NOLOCK)
                            WHERE Key1 = @c_OrderKey AND Key3 = @c_StorerKey AND TableName = 'PREINVLOG')
            BEGIN
               IF @c_authority_pickcfmlog = '1' AND @c_Status = '5'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'PICKCFMLOG', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
            END
         END
         ELSE
         BEGIN
            -- Added By Vicky on 11 Oct 2005
            -- Generic PickConfirm Interface - Start
            IF @c_authority_pickcfmlog = '1' AND @c_Status = '5' AND (@c_PrevSTATUS <> @c_Status) -- SOS#129033
            BEGIN
               EXEC dbo.ispGenTransmitLog3 'PICKCFMLOG', @c_OrderKey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END

               -- (MC08) - S -- Handle Repack
               IF @c_authority_REInstTL3 = '1'
               BEGIN
                  EXEC dbo.ispReGenTransmitLog3 'PICKCFMLOG', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END
               -- (MC08) - E
            END
            -- Generic PickConfirm Interface - End
         END
      END
      -- (YokeBeen02) End

      -- (MC05) - S
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_VPackLog = '1' AND @c_Status = '5' AND (@c_PrevSTATUS <> @c_Status)
         BEGIN
            EXEC dbo.ispGenVitalLog 'VPACKLOG', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
             , @n_err OUTPUT
                           , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      -- (MC05) - E
      -- (MC06) - S
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_PickInMail = '1' AND ( @c_CurSOStatus = '3' OR @c_Status = '3' )
         BEGIN
            EXEC dbo.ispGenTransmitLog3 'PICKINMAIL', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
         END
      END
      -- (MC06) - E
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_nwitf = '1'
         BEGIN
            IF (@c_CurSOStatus = '9' AND @c_PrevSTATUS = '0')
            BEGIN
               IF ( SELECT CONVERT(CHAR(10),codelkup.notes) FROM codelkup WITH (NOLOCK)
                      JOIN orders WITH (NOLOCK) ON (Codelkup.code = Orders.type)
                     WHERE Orders.Orderkey = @c_Orderkey
                     AND Codelkup.listname = 'ORDERTYPE'
                     AND Codelkup.long = @c_StorerKey ) = 'RTV'
               BEGIN
                  -- SOS27626
                  --EXEC dbo.ispGenTransmitLog2 'NWSHPRTV', @c_OrderKey, '', @c_StorerKey, ''
                  EXEC dbo.ispGenTransmitLog3 'NWSHPRTV', @c_OrderKey, '', @c_StorerKey, ''       -- SOS27626
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
               END
               ELSE
               BEGIN
                  -- SOS27626
                  -- EXEC dbo.ispGenTransmitLog2 'NWSHPTRF', @c_OrderKey, '', @c_StorerKey, ''
                  EXEC dbo.ispGenTransmitLog3 'NWSHPTRF', @c_OrderKey, '', @c_StorerKey, ''       -- SOS27626
                                 , @b_success OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT
          END

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62925   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': EXECUTE NW Interface fail. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            ELSE
            BEGIN
               IF (@c_CurSOStatus < '9' AND @c_PrevSTATUS = '9')
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62926   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Interface Has Trigger, No Update allowed. (ntrOrderHeaderUpdate) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
         END
      END

      -- Added by RickyYee on 19-Oct-2004 (Carrefour Gold Interface - start)
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_c4itf = '1'
         BEGIN
            IF (@c_CurSOStatus = 'CANC' AND @c_PrevSTATUS = '0')
            BEGIN
               EXEC dbo.ispGenTransmitLog2 'C4SHPCF', @c_OrderKey, '', @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

           IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62927   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': EXECUTE C4 Interface fail. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
            ELSE
            BEGIN
               IF (@c_CurSOStatus <> 'CANC' AND @c_PrevSTATUS = 'CANC')
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62928   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Interface Has Trigger, No Update allowed. (ntrOrderHeaderUpdate) ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
              END
            END
         END
      END
      -- Added by RickyYee on 19-Oct-2004 (Carrefour Gold Interface - End)

      IF @c_authority_nkreg = '1' AND @c_CurSOStatus IN ('CANC', 'SHORTSHIP') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_OrdType <> 'M' AND @c_CurSOStatus = 'CANC'
         BEGIN
            -- Modified By Shong on 18-Mar-2004 For NIKE Regional (NSC) Project - (SOS#20000)
            -- Changed to trigger records into NSCLog table with 'NSCKEY'.
            EXEC dbo.ispGenNSCLog 'NIKEREGCSO', @c_OrderKey, '', @c_StorerKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
            -- End Modified By Shong on 18-Mar-2004 For NIKE Regional (NSC) Project (SOS#20000)
         END -- Order type <> M
         ELSE IF @c_OrdType <> 'M' AND @c_CurSOStatus = 'SHORTSHIP'
         BEGIN
            -- Modified By Shong on 24-Mar-2004 For NIKE Regional (NSC) Project - (SOS#20000)
            -- Changed to trigger records into NSCLog table with 'NSCKEY'.
            EXEC dbo.ispGenNSCLog 'NIKEREGORD', @c_OrderKey, '', @c_StorerKey, ''
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
            -- End Modified By Shong on 18-Mar-2004 For NIKE Regional (NSC) Project (SOS#20000)
     END -- Order type <> M

      END

      -- Added by SHONG ON 09-Jun-2005
      -- Generic Ship Confirm Interface
      IF @c_authority_socfm = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'SOCFMLOG', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      -- (MC03) - S
      -- Generic Alternate Ship Confirm Interface
      IF @c_authority_socfm2 = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'SOCFM2LOG', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (MC03) - E

      -- (MC07) - S
      -- Generic CMS Ship Confirm Interface
IF @c_authority_SOShpCfmCMS = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC ispGenCMSLog 'SOSHPCFMCMS', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (MC07) - E

      --(KT01) - Start
      IF @c_authority_crshpcfm = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'WSCRSOCFM', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      IF @c_authority_crshpcfm2 = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'WSCRSOCFM2', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      --(KT01) - End

      -- (MC04) - S
      -- Generic Loreal Anti Division Interface
      IF @c_authority_LorAdv = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF EXISTS (SELECT 1 FROM SerialNo WITH (NOLOCK)
                    WHERE OrderKey = @c_OrderKey
          AND STATUS <> '9' )
         BEGIN
            EXEC dbo.ispGenTransmitLog2 'LORADV', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN

               UPDATE SerialNo
               SET STATUS = '9',
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
               WHERE OrderKey = @c_OrderKey
               AND STATUS <> '9'

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err=62931
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Update Failed On Table SERIALNO. (ntrOrderHeaderUpdate)'
               END

        END
         END
      END
      -- (MC04) - E

      -- (YokeBeen01) Start
      IF @c_authority_pickinprog = '1' AND (@c_CurSOStatus = 'CANC' OR @c_Status = 'CANC') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'PICKINPROG', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (YokeBeen01) End

      -- (YokeBeen02) Start
      IF @c_authority_preinvitf = '1' AND (@c_CurSOStatus = 'PREINV') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'PREINVLOG', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (YokeBeen02) End

      -- (YokeBeen03) Start
      IF @c_authority_socfmwow = '1' AND (@c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'SOCFMWOW', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (YokeBeen03) End

      -- Added by MaryVong on 08-Mar-2007
      -- Generic Cancelled Order Interface
      IF @c_authority_cancso = '1' AND ( @c_CurSOStatus = 'CANC' OR @c_Status = 'CANC') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'CANCSOLOG', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
        END
      END

      --(KT01) - Start
      IF @c_authority_crcancso = '1' AND ( @c_CurSOStatus = 'CANC' OR @c_Status = 'CANC') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'WSCRSOCANC', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      --(KT01) - End

      -- (MC01) Start
      -- Generic CMS Cancelled Order Interface
      IF @c_authority_canccmsso = '1' AND ( @c_CurSOStatus = 'CANC' OR @c_Status = 'CANC') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenCMSLog 'SOCANCCMS', @c_OrderKey, 'S', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END
      -- (MC01) END

      -- (MC02) Start
      -- Generic 3PL Order Interface
      IF @c_authority_so3pl = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'SO3PLLOG', @c_OrderKey, @c_Specialhandling, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT

         IF @b_success <> 1
         BEGIN                SELECT @n_continue = 3
         END
      END
      -- (MC02) END

      -- Added by MaryVong ON 04-Jun-2008
      -- FBR107528 POS Interface
      IF @c_authority_positf = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenTransmitLog3 'WMSPOS', @c_OrderKey, @c_OrdType, @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
         END
      END

      -- Added by MCTANG on 31-Jul-2008 (SOS#110280 Vital WMS Ship Confirm) - Start
      IF @c_authority_vshplog = '1' AND ( @c_CurSOStatus = '9' OR @c_Status = '9') AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         EXEC dbo.ispGenVitalLog 'VSHPLOG', @c_OrderKey, '', @c_StorerKey, ''
                           , @b_success OUTPUT
                           , @n_err OUTPUT
                           , @c_errmsg OUTPUT
         IF @b_success <> 1
       BEGIN
            SELECT @n_continue = 3
         END
      END
      -- Added by MCTANG on 31-Jul-2008 (SOS#110280 Vital WMS Ship Confirm) - End

      IF (@n_continue = 1 or @n_continue=2 ) AND @c_billing  = '1'
      BEGIN
         IF @n_ContainerQty > @n_BilledContainerQty AND
            ISNULL(dbo.fnc_RTrim(@c_ContainerType), '') <> '' AND
            ISNULL(@n_ContainerQty,0) <> 0
         BEGIN
            IF EXISTS (SELECT 1 FROM ORDERDETAIL WITH (NOLOCK) WHERE OrderKey = @c_orderkey and ShippedQty > 0 )
            BEGIN
               SELECT @n_Qtytobill = @n_ContainerQty - @n_BilledContainerQty
               EXECUTE nspBillContainer @c_sourcetype = 'SO', @c_sourcekey     = @c_orderkey,
                       @c_ContainerType = @c_ContainerType,   @n_ContainerQty  = @n_Qtytobill,
                       @c_storerkey     = @c_storerkey,       @b_Success       = @b_Success   OUTPUT,
                       @n_err           = @n_err OUTPUT,      @c_errmsg        = @c_errmsg    OUTPUT

              IF NOT @b_Success = 1
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62929   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': EXECUTE nspBillContainer fail. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
         END
      END -- (@n_continue = 1 or @n_continue=2 ) AND @c_billing  = '1'

      -- Order Detail Loop
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority = 1
      BEGIN
         SELECT @c_OrderLineNumber = SPACE(5)
         DECLARE OrdLineCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT OD.Orderlinenumber
         FROM   ORDERDETAIL OD WITH (NOLOCK)
         WHERE  OD.Orderkey = @c_OrderKey

         OPEN OrdLineCur

         FETCH NEXT FROM OrdLineCur INTO @c_OrderLineNumber
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            -- 2 MArch 2005 YTWan sos#33006 - No Despatch Advise if Direct Shipped - START
            -- Add if Status = '9', Insert record to Transmitlog & Invrptlog
            IF @c_authority = 1  AND ( @n_OpenQty = 0 OR @c_CurSOStatus = '9' OR @c_Status = '9')
            BEGIN
               EXEC dbo.ispGenTransmitLog 'ORDDETAIL', @c_OrderKey, @c_OrderLineNumber, '', ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
               END

               EXEC dbo.ispGenInvRptLog 'ORDDETAIL', @c_OrderKey, @c_OrderLineNumber, '', ''
                              , @b_success OUTPUT
                              , @n_err OUTPUT
                              , @c_errmsg OUTPUT
               IF @b_success <> 1
         BEGIN
                  SELECT @n_continue = 3
               END
            END
            FETCH NEXT FROM OrdLineCur INTO @c_OrderLineNumber
         END -- while order lines
         CLOSE OrdLineCur
     DEALLOCATE OrdLineCur
      END -- continue
      -- End Order Detail Loop

      -- tlting06
      IF @c_OrdStatus <> @c_Status AND (@n_continue = 1 OR @n_continue = 2)
      BEGIN
--         IF @c_OrdStatus  = '3' and @c_Status in ('1','2')
--         BEGIN
--            SELECT @c_status = @c_OrdStatus
--         END

         EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @c_OrderKey, '', @c_OrdStatus, @c_Status
              , @b_success OUTPUT
              , @n_err OUTPUT
              , @c_errmsg OUTPUT

         IF NOT @b_success=1
         BEGIN
            SELECT @n_continue=3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62930   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Insert Into DocStatusTrack Table (ORDERS) Failed (ntrOrderHeaderUpdate) ( '
                             + ' SQLSvr MESSAGE=' + ISNULL(RTrim(@c_errmsg),'') + ' ) '
         END
      END -- @c_OrdStatus <> @c_Status
 -- end -- SOS#39993

      -- TLTING10  -- tlting09
      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         SET @c_SINGLE_Multi_Flag = 'S'

         IF @c_Status = '0' AND @c_DocType = 'E'  -- tlting09
         BEGIN
            SELECT @c_SINGLE_Multi_Flag = CASE WHEN ISNULL(SUM(EnteredQTY), 0) > 1 THEN 'M' ELSE 'S' END  -- single\multi Orders
            FROM Orderdetail (NOLOCK)
            WHERE OrderKey = @c_OrderKey
         END

      END


      IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         IF @c_authority_owitf = '1' AND (UPDATE (ConsigneeKey) OR UPDATE(BillToKey))
         BEGIN
            UPDATE ORDERS
            SET STATUS = @c_Status,
                Editdate = getdate(),
                Editwho = sUser_sName(),
                --GOH01 Start
                --ORDERS.B_Vat = STORER.CreditLimit,
                B_Vat = CASE WHEN ISNUMERIC(STORER.CreditLimit) = 1 THEN
                                  CASE WHEN CAST(CAST(STORER.CreditLimit AS FLOAT) AS INT) > 0 THEN -- SOS# 242563
                                            STORER.CreditLimit
                                       ELSE B_VAT
                                  END
                             ELSE B_VAT
                  END,
                --GOH01 End
                UserDefine08 = @c_UserDefine08,
                BilledContainerQty =  CASE WHEN @c_Billing = '1' Then ORDERS.ContainerQty
                                      ELSE ORDERS.BilledContainerQty
                                      END,
                C_Company = Consignee.Company,
                C_Address1 = Consignee.Address1,
                C_Address2 = Consignee.Address2,
                C_Address3 = Consignee.Address3,
                C_Address4 = Consignee.Address4,
                B_Company  = BillTo.Company,
                B_Address1 = BillTo.Address1,
                B_Address2 = BillTo.Address2,
                B_Address3 = BillTo.Address3,
                B_Address4 = BillTo.Address4,
                Route = CASE WHEN dbo.fnc_RTrim(ORDERS.Route) IS NULL THEN '00000'
                            ELSE ORDERS.Route
                       END,
                Trafficcop = NULL,
                ECOM_SINGLE_Flag = CASE WHEN @c_Status = '0' AND ORDERS.DocType = 'E' THEN @c_SINGLE_Multi_Flag ELSE ECOM_SINGLE_Flag END
                        -- TLTING10 -- tlting09
            FROM ORDERS WITH (NOLOCK)
            JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
            LEFT OUTER JOIN STORER AS Consignee WITH (NOLOCK) ON (Consignee.Storerkey = ORDERS.ConsigneeKey)
            LEFT OUTER JOIN Storer AS BillTo WITH (NOLOCK) ON ( BillTo.StorerKey = ORDERS.BillToKey )
            WHERE OrderKey = @c_OrderKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Update Failed On ORDERS. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            SET @c_StatusUpdated = 'Y' -- (MC09)

         END
         ELSE
         BEGIN
            -- Modify by ricky (Feb,2005) to prevent the orders status rollback to 1 or 2 when 3
            UPDATE ORDERS
            SET STATUS = CASE WHEN ORDERS.STATUS = '3' and @c_Status in ('1','2') THEN ORDERS.STATUS
                                     ELSE @c_status
                         END,
                Editdate = getdate(),
                Editwho = SUSER_SNAME(),
                --GOH01 Start
                --ORDERS.B_Vat = STORER.CreditLimit,
                B_Vat = CASE WHEN ISNUMERIC(STORER.CreditLimit) = 1 THEN
                                  CASE WHEN CAST(CAST(STORER.CreditLimit AS FLOAT) AS INT) > 0 THEN -- SOS# 242563
                                            STORER.CreditLimit
                                       ELSE B_VAT
                                  END
                              ELSE B_VAT END,
                --GOH01 End
                UserDefine08 = @c_UserDefine08,
                BilledContainerQty = CASE WHEN @c_Billing = '1' Then ORDERS.ContainerQty
                                          ELSE ORDERS.BilledContainerQty
                                     END,
                SOStatus = CASE WHEN @c_SetSOStatusWhileStatusChange = '1' AND @c_NewSOStatus <> '' THEN
                                     @c_NewSOStatus
                           ELSE SOStatus
                           END, -- Shong002
                Trafficcop = NULL,
                ECOM_SINGLE_Flag = CASE WHEN @c_Status = '0' AND ORDERS.DocType = 'E' THEN @c_SINGLE_Multi_Flag ELSE ECOM_SINGLE_Flag END
                                 -- TLTING10  -- tlting09
            FROM ORDERS
            JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
            WHERE OrderKey = @c_OrderKey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Update Failed On ORDERS. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END

            SET @c_StatusUpdated = 'Y' -- (MC09)

         END
      END

   IF (@n_continue = 1 OR @n_continue = 2)
      BEGIN
         -- Modify by ricky (Feb,2005) to prevent the orders status rollback to 1 or 2 when 3
         UPDATE LOADPLANDETAIL
               SET STATUS = CASE WHEN STATUS = '3' and @c_Status in ('1','2') THEN STATUS
                                      ELSE @c_status
                            END,
             Editdate = getdate(),
             Editwho = SUSER_SNAME(),
             Trafficcop = null
         WHERE Orderkey = @c_OrderKey

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Update Failed On LoadPlan Detail. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                             + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      END

      -- Added By SHONG on Delete PickDetail
      -- When no PickDetail is Exists and QtyAllocated + QtyPicked = 0
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_authority_owitf <> 1 AND @c_Status = '0'
      BEGIN
         IF NOT EXISTS (SELECT PickDetailKey FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @c_OrderKey )
         BEGIN
            IF EXISTS (SELECT PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey
                          AND Zone IN ('3','8'))   --SOS350474
            BEGIN
               DELETE PICKHEADER
               WHERE OrderKey = @c_OrderKey
                 AND Zone IN ('3','8') --SOS350474

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Delete PickHeader Failed. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
         END
      END
      --- Added by ChewKP SOS# 143271  -- Update ExternOrderkey in OrderDetail.  (START) ---
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_PrevExternOrderKey <> @c_ExternOrderKey
      BEGIN

     DECLARE OrddetCur1 CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
        SELECT ORDERDETAIL.OrderLineNumber
        FROM   ORDERDETAIL With (NOLOCK)
          WHERE OrderKey = @c_OrderKey AND ExternOrderKey = @c_PrevExternOrderKey

     OPEN OrddetCur1

       FETCH NEXT FROM OrddetCur1 INTO @cOrderLineNumber

       WHILE (@@FETCH_STATUS <> -1)
       BEGIN -- while detail OrddetCur1

          UPDATE ORDERDETAIL
             SET ExternOrderKey = @c_ExternOrderKey, TrafficCop=NULL, EditWho = sUser_sName(),
                 EditDate = GetDate()
          WHERE OrderKey = @c_OrderKey AND ExternOrderKey = @c_PrevExternOrderKey
          AND  OrderLineNumber = @cOrderLineNumber
          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63111   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                              + ': Update OrderDetail Failed. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
              + RTrim(@c_errmsg) + ' ) '
          END

        FETCH NEXT FROM OrddetCur1 INTO @cOrderLineNumber
       END -- detail OrddetCur1
       CLOSE OrddetCur1
       DEALLOCATE OrddetCur1
      END
      --- Added by ChewKP SOS# 143271  -- Update ExternOrderkey in OrderDetail.  (END) ---
      FETCH NEXT FROM ORDCUR INTO @c_Orderkey
   END -- while orderkey
   CLOSE ORDCUR
   DEALLOCATE ORDCUR
   -- End Order Header Loop
END
   /* #INCLUDE <TROHU1.SQL> */

-- (Wan03) - START
IF (@n_continue = 1 OR @n_continue = 2) OR @cTransFlag = '1'
    OR (@c_TrafficCopAllowSOStatusUpd = 'Y' AND @n_continue <> 3)  --NJOW04
    OR (@c_TrafficCopAllowEPACKStatusUpd = 'Y' AND @n_continue <> 3) --(Wan06)
BEGIN
   IF UPDATE(SOStatus)
      OR @c_TrafficCopAllowSOStatusUpd = 'Y' --NJOW04
      OR @c_TrafficCopAllowEPACKStatusUpd = 'Y'                      --(Wan06)
   BEGIN
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT INSERTED.Orderkey
            ,INSERTED.Storerkey
            ,ORDERS.SOStatus
            ,DELETED.SOStatus                      --(Wan04)
      FROM INSERTED WITH (NOLOCK)
      JOIN DELETED WITH (NOLOCK) ON (INSERTED.Orderkey = DELETED.Orderkey)
      JOIN ORDERS WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey) --NJOW04
      AND  ORDERS.SOStatus <> DELETED.SOStatus

      OPEN CUR_ORD

      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
                                 , @c_Storerkey
                                 , @c_CurSOStatus
                                 , @c_DelSOStatus  --(Wan04)

      WHILE @@FETCH_STATUS <> -1 AND @n_continue <> 3
      BEGIN
         SET @c_Status_PTD = '0' --(Wan04)
         SET @c_DelStatus_PTD = '0'                --(Wan04)

         SET @b_UpdatePackTaskDetail = 0
         IF @c_CurSOStatus IN ('CANC', 'HOLD')
         BEGIN
            --SET @b_UpdatePackTaskDetail = 1      --(Wan04)
            SET @c_Status_PTD = 'X'                --(Wan04)
         END

         --IF @b_UpdatePackTaskDetail = 0
         IF @c_Status_PTD = '0'                    --(Wan04)
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM CODELKUP WITH (NOLOCK)
                        WHERE ListName = 'NONEPACKSO'
                        AND   Code = @c_CurSOStatus
                        AND   (Storerkey = @c_Storerkey OR Storerkey = '')
                      )
            BEGIN
               --SET @b_UpdatePackTaskDetail = 1   --(Wan04
               SET @c_Status_PTD = 'X'             --(Wan04)
            END
         END

         --(Wan04) - START
         IF @c_DelSOStatus IN ('CANC', 'HOLD')
         BEGIN
            SET @c_DelStatus_PTD = 'X'
         END

         IF @c_DelStatus_PTD = '0'
         BEGIN
            IF EXISTS ( SELECT 1
                        FROM CODELKUP WITH (NOLOCK)
                        WHERE ListName = 'NONEPACKSO'
                        AND   Code = @c_DelSOStatus
                        AND   (Storerkey = @c_Storerkey OR Storerkey = '')
                        )
            BEGIN
               SET @c_DelStatus_PTD = 'X'
            END
         END

         IF @c_Status_PTD <> @c_DelStatus_PTD
         BEGIN
            SET @b_UpdatePackTaskDetail = 1
         END
         --(Wan04) - END

         IF @b_UpdatePackTaskDetail = 1
         BEGIN
            --(Wan05) - START: NIKESDC's Order SOStatus when change when request tracking # even if PACK is confirmed
            SET @c_PickSlipNo = ''

            IF @c_Status_PTD <> 'X'
            BEGIN
               SET @c_PackStatus = '0'
               SELECT @c_PickSlipNo = PickSlipNo
                     ,@c_PackStatus = Status
               FROM PACKHEADER WITH (NOLOCK)
               WHERE Orderkey = @c_Orderkey

               IF @c_PickSlipNo <> ''
               BEGIN
                 SET @c_Status_PTD = '3'
               END

               IF @c_PackStatus = '9'
               BEGIN
                 SET @c_Status_PTD = @c_PackStatus
               END
            END
            --(Wan05) - END

            DECLARE CUR_UPDPTD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM PACKTASKDETAIL WITH (NOLOCK)
            WHERE Orderkey = @c_Orderkey
            --AND   Status   = '0'                 --(Wan04)

            OPEN CUR_UPDPTD

            FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef

            WHILE @@FETCH_STATUS <> -1 AND @n_continue <> 3
            BEGIN
               UPDATE PACKTASKDETAIL
               --SET Status     = 'X'              --(Wan04)
               SET Status     = @c_Status_PTD      --(Wan04)
                  ,PickSlipNo = @c_PickSlipNo      --(Wan05)
                  ,EditWho    = SUSER_NAME()
                  ,EditDate   = GETDATE()
                  ,TrafficCop = NULL
               WHERE RowRef = @n_RowRef

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(CHAR(250),@n_err)
                  SET @n_err=63113   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Update Failed On PACKTASKDETAIL. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END

               FETCH NEXT FROM CUR_UPDPTD INTO @n_RowRef
            END
            CLOSE CUR_UPDPTD
            DEALLOCATE CUR_UPDPTD
         END

         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
                                    , @c_Storerkey
                                    , @c_CurSOStatus
                                    , @c_DelSOStatus  --(Wan04)
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END
END
-- (Wan03) - END

-- Trigger Event for Loadplan Insert Trigger
IF @n_continue = 1 or @n_continue=2
BEGIN
   DECLARE @c_LP_Min_Status NVARCHAR(10),
           @c_LP_Max_Status NVARCHAR(10),
           @c_LP_Cur_Status NVARCHAR(10) ,
           @c_LP_New_Status NVARCHAR(10)

   DECLARE @cDoNotCalcLPAllocInfo VARCHAR(10)

   IF NOT EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK) JOIN STORERCONFIG WITH (NOLOCK)
                     ON INSERTED.StorerKey = STORERCONFIG.StorerKey
                WHERE ConfigKey = 'UCCTracking'
                     AND SValue = '1')
   BEGIN
      SET @c_Loadkey = ''

      DECLARE CUR_LOAD_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LoadPlan.LoadKey, LoadPlan.[Status], INSERTED.StorerKey
      FROM  INSERTED
      JOIN  LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = INSERTED.OrderKey)
      JOIN  LoadPlan WITH (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
      WHERE LoadPlan.Status BETWEEN '0' AND '5'

      OPEN CUR_LOAD_UPDATE
      FETCH NEXT FROM CUR_LOAD_UPDATE INTO @c_Loadkey, @c_LP_Cur_Status, @c_StorerKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cDoNotCalcLPAllocInfo = '0'

         SELECT @cDoNotCalcLPAllocInfo = ISNULL(sValue, '0')
         FROM  STORERCONFIG WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND   ConfigKey = 'DoNotCalcLPAllocInfo'
         AND   sVAlue = '1'

         SELECT @c_LP_Min_Status = '0',
                @c_LP_Max_Status = '0',
                @c_LP_New_Status = '0'

         SELECT @c_LP_Min_Status = MIN(STATUS),
                @c_LP_Max_Status = MAX(STATUS)
         FROM   LoadPlanDetail AS lpd WITH (NOLOCK)
         WHERE  lpd.LoadKey = @c_Loadkey
         AND    lpd.[Status] NOT IN ('CANC')

         SET @c_LP_New_Status = CASE
                                   WHEN @c_LP_Max_Status = '0' THEN '0'
                                   WHEN @c_LP_Min_Status = '0' and @c_LP_Max_Status IN ('1','2')
                                      THEN '1'
                                   WHEN @c_LP_Min_Status IN ('0','1','2') AND @c_LP_Max_Status IN ('3','5')
                                      THEN '3'
                                   ELSE @c_LP_Min_Status
                                END
         SET @c_Col5 = ''
         IF @cDoNotCalcLPAllocInfo <> '1' OR  @c_LP_New_Status <> @c_LP_Cur_Status
         BEGIN
            --SET @c_Col5 = 'Upd LP'
            IF EXISTS(SELECT 1 FROM LoadPlan WITH (NOLOCK)
                      WHERE Loadkey = @c_Loadkey
                      AND   LoadPlan.Status BETWEEN '0' AND '5' )
            BEGIN
               UPDATE LoadPlan
                  SET EditDate = GetDate(), EditWho = SUSER_SNAME()
               WHERE Loadkey = @c_Loadkey
               -- AND   LoadPlan.Status BETWEEN '0' AND '5'
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63110
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Update Failed On LoadPlan. (ntrOrderHeaderUpdate) ( SQLSvr MESSAGE='
                                   + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END

            --SET @c_TraceName = 'ntrOrderHeaderUpdate-LP'
            --SET @d_step1 = GETDATE()  -- (tlting01)
            --SET @c_Col1 = @c_Loadkey
            --SET @c_Col2 = @c_StorerKey
            --SET @c_Col3 = @c_LP_Cur_Status
            --SET @c_Col4 = @c_LP_New_Status

            --SET @d_endtime = GETDATE()
            --INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,
            --                       Step1, Step2, Step3, Step4, Step5,
            --                       Col1, Col2, Col3, Col4, Col5)
            --VALUES
 -- (RTRIM(@c_TraceName), @d_starttime, @d_endtime
            -- ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
            -- ,CONVERT(CHAR(12),@d_step1,114)
            -- ,@c_LP_Min_Status
            -- ,@c_LP_Max_Status
            -- ,@cDoNotCalcLPAllocInfo
            -- ,@c_OrderKey
            -- ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

            --SET @d_step1 = NULL
            --SET @d_step2 = NULL
            --SET @d_step3 = NULL
            --SET @d_step4 = NULL
            --SET @d_step5 = NULL
         END -- IF @cDoNotCalcLPAllocInfo <> '1' OR  @c_LP_New_Status <> @c_LP_Cur_Status


         FETCH NEXT FROM CUR_LOAD_UPDATE INTO @c_Loadkey, @c_LP_Cur_Status, @c_StorerKey
      END
      CLOSE CUR_LOAD_UPDATE
      DEALLOCATE CUR_LOAD_UPDATE

   END
END -- IF @n_continue = 1 or @n_continue=2

IF @n_continue = 1 or @n_continue=2
BEGIN
   IF UPDATE(GrossWeight) OR UPDATE(Capacity)
   BEGIN
      IF EXISTS (SELECT 1 FROM MbolDetail WITH (NOLOCK)
                   JOIN INSERTED ON (MbolDetail.orderkey = INSERTED.orderkey))
      BEGIN
         UPDATE Mboldetail
         SET Mboldetail.GrossWeight = INSERTED.GrossWeight,
             Mboldetail.Capacity = INSERTED.Capacity,
             TrafficCop = NULL,
             EditDate = GETDATE(),        --tlting
             EditWho = SUSER_SNAME()
         FROM  MbolDetail
         JOIN  INSERTED ON (MbolDetail.Orderkey = INSERTED.orderkey)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err=62931
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                             + ': Update Failed On Table ORDERS. (ntrOrderHeaderUpdate)'
         END
      END
   END
END

--(Wan07) - START
IF @n_continue = 1 or @n_continue=2
BEGIN
   DECLARE @c_Wavekey         NVARCHAR(10) = ''
         , @c_Wv_Cur_Status   NVARCHAR(10) = ''
         , @CUR_WAVE_UPDATE   CURSOR

   SET @CUR_WAVE_UPDATE = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT w.Wavekey, w.[Status], INSERTED.StorerKey
   FROM  INSERTED
   JOIN  dbo.ORDERS WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey AND INSERTED.StorerKey = ORDERS.StorerKey ) --JSM-51565
   JOIN  DELETED ON (DELETED.Orderkey = ORDERS.Orderkey AND DELETED.StorerKey = ORDERS.StorerKey )
   JOIN  dbo.WAVEDETAIL AS wd WITH (NOLOCK) ON (wd.OrderKey = INSERTED.OrderKey)
   JOIN  dbo.WAVE       AS w  WITH (NOLOCK) ON (wd.Wavekey  = w.Wavekey)
   WHERE w.[Status] BETWEEN '0' AND '5'
   AND DELETED.[Status] <> ORDERS.Status

   OPEN @CUR_WAVE_UPDATE

   FETCH NEXT FROM @CUR_WAVE_UPDATE INTO @c_Wavekey, @c_Wv_Cur_Status, @c_StorerKey
   WHILE @@FETCH_STATUS = 0 AND @n_continue = 1
   BEGIN
      EXEC [dbo].[isp_GetWaveStatus]
         @c_WaveKey    = @c_WaveKey
      ,  @b_UpdateWave = 1                         --1 => yes, 0 => No
      ,  @c_Status     = @c_Wv_Cur_Status OUTPUT
      ,  @b_Success    = @b_Success       OUTPUT
      ,  @n_Err        = @n_Err           OUTPUT
      ,  @c_ErrMsg     = @c_ErrMsg        OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_continue = 3
      END

      FETCH NEXT FROM @CUR_WAVE_UPDATE INTO @c_Wavekey, @c_Wv_Cur_Status, @c_StorerKey
   END
   CLOSE @CUR_WAVE_UPDATE
   DEALLOCATE @CUR_WAVE_UPDATE
END -- IF @n_continue = 1 or @n_continue=2
--(Wan07) - END

--NJOW02 --NJOW03 move from Top
IF @n_continue=1 or @n_continue=2
   or (@c_TrafficCopAllowTriggerSP = 'Y' AND @n_continue <> 3) --NJOW03
BEGIN
   IF EXISTS (SELECT 1 FROM DELETED d
              JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
              JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
              WHERE  s.configkey = 'OrdersTrigger_SP')
   BEGIN
      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

       SELECT *
       INTO #INSERTED
       FROM INSERTED

      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED

       SELECT *
      INTO #DELETED
       FROM DELETED

      EXECUTE dbo.isp_OrdersTrigger_Wrapper
                'UPDATE'  --@c_Action
              , @b_Success  OUTPUT
              , @n_Err      OUTPUT
              , @c_ErrMsg   OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrOrderHeaderUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
      END

      IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
         DROP TABLE #INSERTED

      IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
         DROP TABLE #DELETED
   END
END



/********************************************************/
/* Interface Trigger Points Calling Process - (Start)   */
/********************************************************/
IF @n_continue = 1 OR @n_continue = 2
   OR (@c_TrafficCopAllowITFTriggerCfg = 'Y' AND @n_continue <> 3)   --WL03
BEGIN
   DECLARE @t_ColumnUpdated TABLE (COLUMN_NAME NVARCHAR(50))

   SET @c_ColumnsUpdated = ''


   DECLARE Cur_Order_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   -- Extract values for required variables
    SELECT DISTINCT INS.ORDERKEY
    FROM INSERTED INS
    JOIN ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey
    WHERE ITC.SourceTable = 'ORDERS'
    AND ITC.sValue      = '1'
    UNION                                                                                           --(MC10)
    SELECT DISTINCT IND.ORDERKEY                                                                    --(MC10)
    FROM   INSERTED IND                                                                             --(MC10)
    JOIN   ITFTriggerConfig ITC WITH (NOLOCK)                                                       --(MC10)
    ON     ITC.StorerKey   = 'ALL'                                                                  --(MC10)
    JOIN   StorerConfig STC WITH (NOLOCK)                                                           --(MC10)
    ON     STC.StorerKey   = IND.StorerKey AND STC.ConfigKey = ITC.ConfigKey AND STC.SValue = '1'   --(MC10)
    WHERE  ITC.SourceTable = 'ORDERS'                                                               --(MC10)
    AND    ITC.sValue      = '1'                                                                    --(MC10)

   OPEN Cur_Order_TriggerPoints
   FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_orderkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      --(MC11) - S
      SET @c_ColumnsUpdated = ''

      IF UPDATE(SOSTATUS)
      BEGIN
         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = 'SOSTATUS'
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'SOSTATUS'
         END
      END

      IF UPDATE(Status) OR @c_StatusUpdated = 'Y'
      BEGIN
         IF @c_ColumnsUpdated = ''
         BEGIN
            SET @c_ColumnsUpdated = 'Status'
         END
         ELSE
         BEGIN
            SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'Status'
         END
      END
      /*
      --(MC09) - S
      IF ISNULL(RTRIM(@c_ColumnsUpdated),'') = ''
      BEGIN
         INSERT INTO @t_ColumnUpdated
         SELECT COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('ORDERS', @b_ColumnsUpdated)

         DECLARE Cur_Order_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT COLUMN_NAME FROM @t_ColumnUpdated
         OPEN Cur_Order_ColUpdated
         FETCH NEXT FROM Cur_Order_ColUpdated INTO @c_COLUMN_NAME
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            IF @c_ColumnsUpdated = ''
            BEGIN
               SET @c_ColumnsUpdated = @c_COLUMN_NAME
            END
            ELSE
       BEGIN
               SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + @c_COLUMN_NAME
            END

            FETCH NEXT FROM Cur_Order_ColUpdated INTO @c_COLUMN_NAME
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE Cur_Order_ColUpdated
       DEALLOCATE Cur_Order_ColUpdated

         IF @c_StatusUpdated = 'Y'
         BEGIN
            IF @c_ColumnsUpdated = ''
            BEGIN
               SET @c_ColumnsUpdated = 'STATUS'
            END
            ELSE
            BEGIN
               SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + 'STATUS'
            END
         END
         --(MC09) - E
      END
      */
      --(MC11) - E

      -- Execute SP - isp_ITF_ntrTransfer
      EXECUTE dbo.isp_ITF_ntrOrderHeader
               @c_TriggerName = 'ntrOrderHeaderUpdate'
             , @c_SourceTable = 'ORDERS'
             , @c_OrderKey    = @c_orderkey
             --, @b_ColumnsUpdated = @b_ColumnsUpdated      --(MC09)
             , @c_ColumnsUpdated = @c_ColumnsUpdated        --(MC09)
             , @b_Success = @b_Success OUTPUT
             , @n_err     = @n_err    OUTPUT
             , @c_errmsg  = @c_errmsg  OUTPUT

      FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_orderkey
   END -- WHILE @@FETCH_STATUS <> -1
   CLOSE Cur_Order_TriggerPoints
   DEALLOCATE Cur_Order_TriggerPoints
END -- IF @n_continue = 1 OR @n_continue = 2

/********************************************************/
/* Interface Trigger Points Calling Process - (End)     */
/********************************************************/

/* #INCLUDE <TROHU2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
   EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'ntrOrderHeaderUpdate'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END


GO