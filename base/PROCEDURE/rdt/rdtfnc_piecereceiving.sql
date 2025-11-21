SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_PieceReceiving                                */
/* Copyright      : Maersk                                               */
/*                                                                       */
/* Purpose: Lookup qualified ReceiptDetail lines to receive in the QTY   */
/*                                                                       */
/* Modifications log:                                                    */
/*                                                                       */
/* Date       Rev   Author    Purposes                                   */
/* 2007-03-20 1.0   Liew      Create                                     */
/*            1.2   Shong     Allow Return Type SOS# 111224              */
/*            1.3   Shong     Support Retail SKU SOS# 111756             */
/* 2009-02-05 1.4   James     SOS128415 - Change declaration of @cQty    */
/*                            from NVARCHAR(2) to NVARCHAR(5) (james01)  */
/* 2008-11-03 1.5   Vicky     Remove XML part of code that is used to    */
/*                            make field invisible and replace with new  */
/*                            code (Vicky02)                             */
/* 2009-02-11 1.6   Rick Liew SOS128806 - Change declaration of          */
/*                            @cTotalCarton,@cTotalQty,@cTempTotalQty    */
/*                            @cCartonCnt from NVARCHAR(2) to NVARCHAR(5)*/
/* 2009-05-07 1.7   Vicky     SOS#135894 - Add checking to not allow     */
/*                            receiving of SKU more than ExpectedQty     */
/*                            (Vicky03)                                  */
/* 2009-05-22 1.8   Vicky     SOS#137402 - Display Long message in next  */
/*                            screen instead of bottom of the screen and */
/*                            Default Qty when QTY field is not disabled */
/*                            (Vicky04)                                  */
/* 2009-07-06 1.9   Vicky     Add in EventLog (Vicky06)                  */
/* 2010-12-22 2.0   ChewKP    Bug Fixes (ChewKP01)                       */
/* 2010-01-13 2.1   ChewKP    SOS#202440 Display Qty Received and Qty    */
/*                            Expected (ChewKP02)                        */
/* 2011-08-03 2.2   Ung       SOS222874:                                 */
/*                            Print pallet label                         */
/*                            Support QTY in decimal                     */
/*                            Support POST lottable processing           */
/*                            Implement storer configuration:            */
/*                               AutoGenID                               */
/*                               ReceiveByPieceCheckIDInASN              */
/*                               ReceiveByPieceDefLottableByID           */
/*                            SOS222875: Print carton label              */
/*                            Clean up source                            */
/* 2011-11-24 2.3  Ung        SOS230666: Chg ReceivingPOKeyDefaultValue  */
/*                            to function level                          */
/*                            Implement storer config SkipLottable0X     */
/* 2012-03-12 2.4  Ung        SOS222875 Add different pallet label       */
/*                            Fix datawindow > 20 chars, truncate error  */
/* 2012-04-04 2.5  Ung        SOS240680 AutoGenID support configurable SP*/
/* 2012-03-23 2.6  Ung        SOS239384 Add SKU decodelabelNo            */
/* 2012-09-04 2.7  Ung        SOS254312 Add ExtendedInfoSP               */
/* 2012-11-21 2.8  James      Bug fix (james02)                          */
/* 2012-11-14 2.9  Ung        SOS261921 Add ConvertQTYSP                 */
/* 2013-01-10 3.0  James      Use CLR type regular expression (james03)  */
/* 2013-04-25 3.1  Ung        SOS276721 Fix UPC allow 30 chars (ung01)   */
/* 2013-04-30 3.2  Ung        SOS276703 Add VerifySKU                    */
/* 2013-05-07 3.3  Ung        SOS275121 Add MultiSKUBarcode              */
/* 2013-04-09 3.4  James      SOS275027 Add ExtendedUpdateSP (james04)   */
/* 2013-06-07 3.5  Ung        SOS273208:                                 */
/*                            Add ExternReceiptKey                       */
/*                            Fix POST lottable SourceKey not set (ung02)*/
/*                            AutoGenID add parameter                    */
/*                            Add SKULabelSP                             */
/* 2013-06-07 3.6  Ung        SOS293944 Change MultiSKUBarcode check     */
/* 2014-02-13 3.7  SPChin     SOS303238 Bug Fixed                        */
/* 2014-04-24 3.8  Ung        SOS308961 PRE POST codelkup with StorerKey */
/* 2014-01-22 3.9  ChewKP     SOS#292548 Bug Fixes (ChewKP03)            */
/* 2014-04-09 4.0  Ung        SOS307644 Add auto match SKU in Doc        */
/* 2014-07-30 4.1  Ung        SOS316652 Add ExtendedValidateSP           */
/* 2014-04-09 4.2  Ung        SOS301005 DecodeLabelNo return L01-L04     */
/* 2014-07-21 4.3  James      SOS315958 - Add ExtendedInfoSP to screen 7 */
/*                            Add ExtendedValidateSP to screen 3(james05)*/
/* 2015-01-02 4.4  Ung        SOS328774 ExtendedUpdateSP add param       */
/*                            Migrate to rdt_VerifySKU                   */
/* 2015-03-19 4.5  James      SOS333459 - Store VerifySKUInfo output into*/
/*                            V_String (james06)                         */
/* 2015-06-18 4.6  James      Cater for skip lottable scenario (james07) */
/* 2016-04-21 4.7  James      SOS367156 - Add receive confirm wrapper    */
/*                            (james08)                                  */
/* 2016-03-01 4.9  ChewKP     SOS#364495 - Add ExtendedValidateSP pass in*/
/*                            Qty parameter (ChewKP04)                   */
/* 2016-05-03 5.0  ChewKP     SOS#368773 - Add Parameter (ChewKP05)      */
/* 2016-08-16 5.1  Ung        SOS375486 Add RDT format for TO ID         */
/* 2016-09-30 5.2  Ung        Performance tuning                         */
/* 2016-11-02 5.3  Ung        Fix recompile due to date format different */
/* 2017-05-05 5.4  Ung        WMS-1817 Add serial no                     */
/* 2017-10-05 5.5  James      WMS-2584 Add filter facility, function_id  */
/*                            for SKULABEL retrieve (james10)            */
/* 2017-10-05 5.6  James      WMS-1895 Add ExtValid into step 4 (james09)*/
/* 2017-01-22 5.7  James      WMS-3791 Change ExtASN lookup into config  */
/*                            (james10)                                  */
/* 2018-04-25 5.8  Ung        WMS-4333 Fix UOMDiv not initialize         */
/* 2018-04-03 5.9  ChewKP     WMS-4126 Fixes (ChewKP06)                  */
/* 2018-06-07 6.0  James      WMS-5313 Add decode for ToID & SKU         */
/* 2018-08-01 6.1  Ung        WMS-5722 Add bulk serial no                */
/* 2018-09-18 6.2  James      WMS-6326 Change SerialNoCapture config     */
/*                            Allow svalue 1 or 2 only (james12)         */
/* 2018-12-28 6.3  TungGH     Fix @cTOID not shown problem               */
/* 2018-09-28 6.4  Ung        INC0406771 Fix bulk serial no              */
/* 2018-10-29 6.5  Gan        Performance tuning                         */
/* 2019-01-03 6.6  James      Allow >18 char pass to TOID decode(james13)*/
/* 2019-03-07 6.7  YeeKung    WMS-8253 Add loc prefix (yeekung01)        */
/* 2019-04-18 6.8  Ung        WMS-8718 Add retain lottable on top of     */
/*                            ReceiveByPieceDefLottableByID              */
/* 2019-06-11 6.9  Ung        Fix QTY field scan barcode runtime error   */
/* 2019-03-07 7.0  James      WMS-8104-Add flow lottable screen (james14)*/
/* 2019-08-13 7.1  James      INC0815024-Bug fix on sku decode (james15) */
/* 2019-09-25 7.2  James      WMS-10434 Add param 2 rdt_serialno(james16)*/
/* 2019-10-02 7.3  KimMun     INC0879172 - Allow QTY field have 7 digits */
/* 2019-11-28 7.4  Grick      INC0951754 - POFlag Cater Blank QTY (G01)  */
/* 2019-11-29 7.5  James      WMS-11215 - Enhance serial no receive. When*/
/*                            return -1 goto sku scn to continue(james17)*/
/* 2020-03-09 7.6  James      WMS-5467 Add extupdsp @ scn 5 (james18)    */
/* 2020-05-10 7.7  James      WMS-9550-Add decode serial no to custom    */
/*                            decode label (james19)                     */
/* 2020-05-05 7.8  Ung        WMS-13066 Pallet label with func, facility */
/* 2020-08-18 7.9  Ung        WMS-14788 Add FlowThruScreen               */
/* 2021-01-12 8.0  James      WMS-16029 Fix date format for extvalid     */
/*                            at step 4 (james20)                        */
/* 2021-01-13 8.1  Chermaine  WMS-15775 Add config after confirmReceive  */
/*                            back to lottable screen (cc01)             */
/* 2021-03-31 8.2  James      WMS-16653 - Add Lottable06 decode (james21)*/
/* 2021-04-01 8.3  James      WMS-16727 Auto go back scn1 when ASN       */
/*                            finish receive (no over receive) (james22) */
/* 2021-01-15 8.4  Chermaine  WMS-16015 Add DecodeLottableSP config      */
/*                            in scn4 and ExtValSP config in scn2(cc02)  */
/* 2021-06-01 8.6  Leong      INC1512999 - Reset variable                */  
/* 2021-06-09 8.5  Chermaine  WMS-16328 Add SuggestLoc in scn1 (cc03)    */  
/*                            and Add ClosePallet SP                     */  
/* 2021-10-15 8.7  James      WMS-18022 Add eventlog to serial no step   */
/*                            Add new field into eventlog (james23)      */
/* 2022-02-24 8.8  Ung        WMS-18950 Add RDT format for Lottable01..4 */
/* 2022-05-19 8.9  Ung        WMS-19667 Migrate to new ExtendedInfoSP    */
/* 2019-04-16 9.0  MT         Add missing nBulkSNOQTY in line 2576       */
/* 2020-12-07 9.1  YeeKung    Change params in decodesku   (yeekung02)   */  
/* 2022-09-02 9.2  James      WMS-20639 Change rdt_GetSKU output         */
/*                            UPC Qty (james24)                          */
/* 2021-10-15 9.3  yeekung    WMS-19640 Add eventlog refno1(yeekung03)   */
/* 2022-10-04 9.4  yeekung    WMS-21405 Add extendedvalidate step 1      */
/*                             (yeekung05)                               */
/* 2023-03-20 9.5  James      WMS-21943 Add Decode into step sku(james25)*/
/* 2023-04-25 9.6  James      Addhoc fix add extendedupdatesp to step    */
/*                            serial no (james26)                        */
/* 2023-05-23 9.7  James      WMS-21975 Add V_Barcode to sku step for    */
/*                            sku input. Add config go back To ID after  */
/*                            each received (james27)                    */
/* 2023-05-11 9.8  Ung        WMS-22366 Fix MultiSKUBarcode with Add SKU */
/*                            in ASN should always prompt, not auto select*/
/* 2023-06-03 9.9  James      Bug fix on V_Barcode input (james28)       */
/* 2023-06-13 10.0 James      WMS-22739 Fix Lottable04 conversion issue  */
/*                            when run DecodeSP (james29)                */
/* 2024-03-13 10.1 Dennis     UWP-15504 Pallet Type Scn                  */

/* 2024-03-11 10.2 Ung        WMS-24798 Add ExtendedScreenSP             */
/* 2024-06-10 10.3 James      Adhoc Fix Lot04 conversion issue (james30) */
/* 2023-06-03 10.4 Ung        WMS-22650 Add DispStyleColorSize           */
/* 2024-06-18 10.5 Dennis     FCR-350 Skip ID screen                     */
/* 2024-06-25 10.6 James      UWP-19305 Fix total serial no scanned must */
/*                            match qty entered only can receive(james31)*/
/* 2024-06-27 10.7 Jackc      Remove ext scn entry from LF in step5      */
/* 2024-07-24 10.8 JHU151     FCR-549 Defy                               */
/* 2024-07-27 10.9 Dennis     Dynamic Lottable                           */
/* 2024-07-31 11.0 JHU151     FCR-550 Scan SN on sku screen              */
/* 2024-12-27 12.0 Dennis     UWP-28649 Fix Capture Pallet Type Bug      */
/************************************************************************/
CREATE   PROC [RDT].[rdtfnc_PieceReceiving] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @b_success               INT,
   @n_err                   INT,
   @c_errmsg                NVARCHAR( 250),
   @cSQL                    NVARCHAR(MAX),
   @cSQLParam               NVARCHAR(MAX),
   @cListName               NVARCHAR(20),
   @cShort                  NVARCHAR(10),
   @cStoredProd             NVARCHAR(250),
   @nCount                  INT,
   @cLottableLabel          NVARCHAR(20),
   @cDisAllowRDTOverReceipt NVARCHAR(1),
   @cDefaultPieceRecvQTY    NVARCHAR(5),
   @nBeforeReceivedQty      INT,
   @nQtyExpected            INT,
   @nCheckQTYFormat         INT,
   @cReceiptLineNumber      NVARCHAR( 5),
   @cSkipLottable           NVARCHAR( 1),
   @cSkipLottable01         NVARCHAR( 1),
   @cSkipLottable02         NVARCHAR( 1),
   @cSkipLottable03         NVARCHAR( 1),
   @cSkipLottable04         NVARCHAR( 1),
   @cWeight                 NVARCHAR( 10),
   @cCube                   NVARCHAR( 10),
   @cLength                 NVARCHAR( 10),
   @cWidth                  NVARCHAR( 10),
   @cHeight                 NVARCHAR( 10),
   @cInnerPack              NVARCHAR( 10),
   @cCaseCount              NVARCHAR( 10),
   @cPalletCount            NVARCHAR( 10),
   @cVerifySKUInfo          NVARCHAR( 20),
   @cOption                 NVARCHAR( 1),
   @cQTY                    NVARCHAR( 10),
   @cBarcode                NVARCHAR( MAX),
   --@cMax                    NVARCHAR( MAX),
   @cSerialNo               NVARCHAR( 30),
   @nSerialQTY              INT,
   @nMoreSNO                INT,
   @nBulkSNO                INT,
   @nBulkSNOQTY             INT,
   @nDecodeQTY              INT, 
   @tVar                    VariableTable,
   @nUPCQty                 INT = 0,
   @nAfterStep              INT, 
   @nAfterScn               INT

-- Define a variable
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorer             NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   @cUserName           NVARCHAR(18),
   @cPrinter            NVARCHAR(10),

   @cReceiptKey         NVARCHAR(10),
   @cPOKey              NVARCHAR(10),
   @cLOC                NVARCHAR(20),
   @cTOID               NVARCHAR(18),
   @cSKU                NVARCHAR(30), --(ung01)
   @cSKUDesc            NVARCHAR( 60),
   @nQTY                INT,
   @cUOM                NVARCHAR( 10),
   @cAutoID             NVARCHAR(18),
   @cPrevBarcode        NVARCHAR(30),
   @nUOM_Div            INT,
   @nToIDQTY            INT,
   @nAction             INT,
   @cPalletType         NVARCHAR(10),
   @cDataWindow         NVARCHAR(50),
   @cTargetDB           NVARCHAR(20),
   @cDecodeLabelNo      NVARCHAR(20),
   @cExtendedInfo       NVARCHAR(20),
   @cExtendedInfoSP     NVARCHAR(20),
   @cConvertQTYSP       NVARCHAR(20),
   @cVerifySKU          NVARCHAR(20),
   @cDispStyleColorSize NVARCHAR(1),
   @cMultiSKUBarcode    NVARCHAR(1),
   @nFromScn            INT,
   @cExtendedScreenSP   NVARCHAR(20),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cAutoGenID          NVARCHAR(20),
   @cSKULabel           NVARCHAR(1),
   @cExtendedValidateSP NVARCHAR(20),
   @cSerialNoCapture    NVARCHAR(1),
   @cClosePallet        NVARCHAR(1),
   @cLottable01         NVARCHAR(18),
   @cLottable02         NVARCHAR(18),
   @cLottable03         NVARCHAR(18),
   @dLottable04         DATETIME,
   @dLottable05         DATETIME,
   @cLottable06         NVARCHAR(30),
   @cTempLottable01     NVARCHAR(20),
   @cTempLottable02     NVARCHAR(20),
   @cTempLottable03     NVARCHAR(20),
   @cTempLottable04     NVARCHAR(16),
   @cTempLottable06     NVARCHAR(30),

   @cExtScnSP           NVARCHAR( 20),

   @cLottableLabel01    NVARCHAR(20),
   @cLottableLabel02    NVARCHAR(20),
   @cLottableLabel03    NVARCHAR(20),
   @cLottableLabel04    NVARCHAR(20),
   @cRefNo              NVARCHAR(20),
   @cStorerGroup        NVARCHAR(20),
   @nRowCount           INT,
   @cDecodeSP           NVARCHAR( 20),
   @cSKUValidated       NVARCHAR( 2),
   @cLOCLookupSP        NVARCHAR(20),  --(yeekung01)
   @nNOPOFlag           INT,
   @cFlowThruScreen     NVARCHAR( 1),
   @cBackToASNScnWhenFullyRcv   NVARCHAR( 1),
   @cAutoGotoLotScn     NVARCHAR( 1), --(cc01)
   @cDecodeLottableSP   NVARCHAR(20), --(cc02)
   @cSuggestedLocSP     NVARCHAR(20), --(cc03)
   @cSuggestedLoc       NVARCHAR(10), --(cc03)
   @cClosePalletSP      NVARCHAR(20), --(cc03)  
   @cClosePalletOut     NVARCHAR(20), --(cc03)
   @cBUSR1              NVARCHAR( 30), -- (james23)
   @cAfterReceiveGoBackToId   NVARCHAR( 1),
   @cLoseIDlocSkipID    NVARCHAR( 1),
   @tExtScnData			VariableTable,
   @cEnableAllLottables NVARCHAR( 1),
   @cLottableCode       NVARCHAR( 30),
   @nMorePage           INT,
   @cMax                NVARCHAR( MAX),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1),


   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   
   @cUDF01  NVARCHAR( 250), @cUDF02 NVARCHAR( 250), @cUDF03 NVARCHAR( 250),
   @cUDF04  NVARCHAR( 250), @cUDF05 NVARCHAR( 250), @cUDF06 NVARCHAR( 250),
   @cUDF07  NVARCHAR( 250), @cUDF08 NVARCHAR( 250), @cUDF09 NVARCHAR( 250),
   @cUDF10  NVARCHAR( 250), @cUDF11 NVARCHAR( 250), @cUDF12 NVARCHAR( 250),
   @cUDF13  NVARCHAR( 250), @cUDF14 NVARCHAR( 250), @cUDF15 NVARCHAR( 250),
   @cUDF16  NVARCHAR( 250), @cUDF17 NVARCHAR( 250), @cUDF18 NVARCHAR( 250),
   @cUDF19  NVARCHAR( 250), @cUDF20 NVARCHAR( 250), @cUDF21 NVARCHAR( 250),
   @cUDF22  NVARCHAR( 250), @cUDF23 NVARCHAR( 250), @cUDF24 NVARCHAR( 250),
   @cUDF25  NVARCHAR( 250), @cUDF26 NVARCHAR( 250), @cUDF27 NVARCHAR( 250),
   @cUDF28  NVARCHAR( 250), @cUDF29 NVARCHAR( 250), @cUDF30 NVARCHAR( 250)

 DECLARE
    @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),
    @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),
    @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),
    @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),
    @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20)

 DECLARE
    @cErrMsg1   NVARCHAR(20), @cErrMsg2    NVARCHAR(20),
    @cErrMsg3   NVARCHAR(20), @cErrMsg4    NVARCHAR(20),
    @cErrMsg5   NVARCHAR(20)

-- Getting Mobile information
SELECT
   @nFunc       = Func,
   @nScn        = Scn,
   @nStep       = Step,
   @nInputKey   = InputKey,
   @cLangCode   = Lang_code,
   @nMenu       = Menu,

   @cFacility   = Facility,
   @cStorer     = StorerKey,
   @cUserName   = UserName,
   @cPrinter    = Printer,

   @cReceiptKey = V_ReceiptKey,
   @cPOKey      = V_POKey,
   @cLOC        = V_LOC,
   @cTOID       = V_ID,
   @cSKU        = V_SKU,
   @cSKUDesc    = V_SKUDescr,
   @nQTY        = V_QTY,
   @cStorerGroup  = StorerGroup,

   @cLottable01 = V_Lottable01,
   @cLottable02 = V_Lottable02,
   @cLottable03 = V_Lottable03,
   @dLottable04 = V_Lottable04,
   @dLottable05 = V_Lottable05,
   @cLottable06 = V_Lottable06,
   @cLottable07 = V_Lottable07,
   @cLottable08 = V_Lottable08,
   @cLottable09 = V_Lottable09,
   @cLottable10 = V_Lottable10,
   @cLottable11 = V_Lottable11,
   @cLottable12 = V_Lottable12,
   @dLottable13 = V_Lottable13,
   @dLottable14 = V_Lottable14,
   @dLottable15 = V_Lottable15,

   @nFromScn    = V_FromScn,
   @cBarcode    = V_Barcode,
   @cMax        = V_Max,
   @nUOM_Div           = V_Integer1,
   @nToIDQTY           = V_Integer2,
   @nBeforeReceivedQty = V_Integer3,
   @nQtyExpected       = V_Integer4,
   @nCheckQTYFormat    = V_Integer5,
   @nNOPOFlag          = V_Integer6,

   @cTempLottable01         = V_String1,
   @cTempLottable02         = V_String2,
   @cTempLottable03         = V_String3,
   @cTempLottable04         = V_String4,
   @cAutoID                 = V_String5,
   @cPrevBarcode            = V_String6,
   @cDisAllowRDTOverReceipt = V_String7,
   @cDefaultPieceRecvQTY    = V_String8,
   @cUOM                    = V_String9,
   @cSkipLottable           = V_String10,
   @cTempLottable06         = V_String11,
   -- @nUOM_Div                = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String10,  5), 0) = 1 THEN LEFT( V_String10,  5) ELSE 0 END,
   -- @nToIDQTY                = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String11,  5), 0) = 1 THEN LEFT( V_String11,  5) ELSE 0 END,
   @cTargetDB               = V_String12,
   @cSkipLottable01         = V_String13,
   @cSkipLottable02         = V_String14,
   @cSkipLottable03         = V_String15,
   @cSkipLottable04         = V_String16,
   @cBackToASNScnWhenFullyRcv = V_String17,
   @cAfterReceiveGoBackToId = V_String18,
   @cDecodeLabelNo          = V_String19,
   @cExtendedInfo           = V_String20,
   @cExtendedInfoSP         = V_String21,
   @cConvertQTYSP           = V_String22,
   @cVerifySKU              = V_String23,
   @cDispStyleColorSize     = V_String24,
   -- @nQtyExpected            = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String25,  5), 0) = 1 THEN LEFT( V_String25,  5) ELSE 0 END,
   @cRefNo                  = V_String26,
   @cMultiSKUBarcode        = V_String27,
   @cExtendedScreenSP       = V_String28, 
   @cExtendedUpdateSP       = V_String29,
   @cAutoGenID              = V_String30,
   @cSKULabel               = V_String31,
   @cExtendedValidateSP     = V_String32,
   @cVerifySKUInfo          = V_String33,
   @cSerialNoCapture        = V_String34,
   @cClosePallet            = V_String35,
   @cDecodeSP               = V_String36,
   @cSKUValidated           = V_String37,
   @cLOCLookupSP            = V_String38, --(yeekung01)
   @cFlowThruScreen         = V_String39,
   @cAutoGotoLotScn         = V_String40, --(cc01)
   @cDecodeLottableSP       = V_String41, --(cc02)
   @cSuggestedLocSP         = V_String42, --(cc03)
   @cClosePalletSP          = V_String43, --(cc03)
   @cExtScnSP               = V_String44,  
   @cEnableAllLottables     = V_String45,
   @cLottableCode           = V_String46,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01  = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02  = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03  = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04  = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05  = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06  = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07  = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08  = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09  = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10  = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11  = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12  = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13  = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14  = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15  = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1580 OR @nFunc = 1581
BEGIN
   IF @nStep =  0 GOTO Step_0   -- Func = 1580. Menu
   IF @nStep =  1 GOTO Step_1   -- Scn = 1750. ASN #
   IF @nStep =  2 GOTO Step_2   -- Scn = 1751. LOC
   IF @nStep =  3 GOTO Step_3   -- Scn = 1752. PAL ID
   IF @nStep =  4 GOTO Step_4   -- Scn = 1753. LOTTABLE
   IF @nStep =  5 GOTO Step_5   -- Scn = 1754. QTY, UOM
   IF @nStep =  6 GOTO Step_6   -- Scn = 1755. Print pallet label?
   IF @nStep =  7 GOTO Step_7   -- Scn = 1756. Verify SKU
   IF @nStep =  8 GOTO Step_8   -- Scn = 3570. Multi SKU Barocde
   IF @nStep =  9 GOTO Step_9   -- Scn = 4831. Serial no
   IF @nStep = 10 GOTO Step_10  -- Scn = 1759. Close pallet?
   IF @nStep = 11 GOTO Step_11  -- Scn = 3990. Dynamic Lottable
   IF @nStep = 12 GOTO Step_12  -- Scn = 4033. SKU
   IF @nStep = 13 GOTO Step_13  -- Scn = 6415. All lottable QTY, UOM
   IF @nStep = 98 GOTO Step_98  -- Extended Screen
   IF @nStep = 99 GOTO Step_99  -- Scn = Customizate screen
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 1580. Menu
 @nStep = 0
********************************************************************************/
Step_0:
BEGIN
   DECLARE @cPOKeyDefaultValue NVARCHAR( 10)

   -- Get storer config
   SET @cClosePallet = rdt.RDTGetConfig( @nFunc, 'ClosePallet', @cStorer)
   SET @cDisAllowRDTOverReceipt = rdt.RDTGetConfig( @nFunc, 'DisAllowRDTOverReceipt', @cStorer)
   SET @cDispStyleColorSize = rdt.RDTGetConfig( @nFunc, 'DispStyleColorSize', @cStorer)
   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorer)
   SET @cLOCLookupSP = rdt.rdtGetConfig(@nFunc,'LOCLookupSP',@cStorer)
   SET @cMultiSKUBarcode = rdt.RDTGetConfig( @nFunc, 'MultiSKUBarcode', @cStorer)
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorer)
   SET @cSkipLottable01 = rdt.RDTGetConfig( @nFunc, 'SkipLottable01', @cStorer)
   SET @cSkipLottable02 = rdt.RDTGetConfig( @nFunc, 'SkipLottable02', @cStorer)
   SET @cSkipLottable03 = rdt.RDTGetConfig( @nFunc, 'SkipLottable03', @cStorer)
   SET @cSkipLottable04 = rdt.RDTGetConfig( @nFunc, 'SkipLottable04', @cStorer)
   SET @cAutoGotoLotScn = rdt.RDTGetConfig( @nFunc, 'AutoGotoLotScn', @cStorer) --(cc01)

   SET @cAutoGenID = rdt.RDTGetConfig( @nFunc, 'AutoGenID', @cStorer)
   IF @cAutoGenID = '0'
      SET @cAutoGenID = ''
   SET @cConvertQTYSP = rdt.RDTGetConfig( @nFunc, 'ConvertQTYSP', @cStorer)
   IF @cConvertQTYSP = '0'
      SET @cConvertQTYSP = ''
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorer)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''
   SET @cDecodeLabelNo = rdt.RDTGetConfig( @nFunc, 'DecodeLabelNo', @cStorer)
   IF @cDecodeLabelNo = '0'
      SET @cDecodeLabelNo = ''
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorer)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''
   SET @cExtendedScreenSP = rdt.RDTGetConfig( @nFunc, '1580ExtendedScreenSP', @cStorer)
   IF @cExtendedScreenSP = '0'
      SET @cExtendedScreenSP = ''
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorer)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorer)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cPOKeyDefaultValue = rdt.RDTGetConfig( @nFunc, 'ReceivingPOKeyDefaultValue', @cStorer)
   IF @cPOKeyDefaultValue = '0'
      SET @cPOKeyDefaultValue = ''
   SET @cVerifySKU = rdt.RDTGetConfig( @nFunc, 'VerifySKU', @cStorer)
   IF @cVerifySKU = '0'    --SOS303238
      SET @cVerifySKU = '' --SOS303238

   SET @cBackToASNScnWhenFullyRcv = rdt.RDTGetConfig( @nFunc, 'BackToASNScnWhenFullyRcv', @cStorer)

   --(cc02)
   SET @cDecodeLottableSP = rdt.RDTGetConfig( @nFunc, 'DecodeLottableSP', @cStorer)
   IF @cDecodeLottableSP = '0'
      SET @cDecodeLottableSP = ''

   --(cc03)
   SET @cSuggestedLocSP = rdt.RDTGetConfig( @nFunc, 'SuggestedLocSP', @cStorer)
   IF @cSuggestedLocSP = '0'
      SET @cSuggestedLocSP = ''
        
   SET @cClosePalletSP = rdt.RDTGetConfig( @nFunc, 'ClosePalletSP', @cStorer)  
   
   -- (james27)
   SET @cAfterReceiveGoBackToId = rdt.RDTGetConfig( @nFunc, 'AfterReceiveGoBackToId', @cStorer)

   SET @cExtScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorer)
   IF @cExtScnSP = '0'
   BEGIN
      SET @cExtScnSP = ''
   END

   -- Code lookup
   IF EXISTS( SELECT 1
      FROM CodeLkup WITH (NOLOCK)
      WHERE ListName = 'RDTFormat'
         AND (Code = '1580-QTY' OR Code = '1581-QTY')
         AND StorerKey = @cStorer)
      SET @nCheckQTYFormat = 1
   ELSE
      SET @nCheckQTYFormat = 0

   -- initialise all variable
   SET @cReceiptKey = ''
   SET @cPOKey= ''
   SET @cLottable01 = ''
   SET @cLottable02 = ''
   SET @cLottable03 = ''
   SET @dLottable04 = NULL
   SET @cVerifySKUInfo = ''
   SET @cSkipLottable = '0'

   SET @cEnableAllLottables = rdt.RDTGetConfig( @nFunc, 'EnableAllLottables', @cStorer)
   IF @cEnableAllLottables = '1'
   BEGIN
      SET @cSkipLottable01 = '1'
      SET @cSkipLottable02 = '1'
      SET @cSkipLottable03 = '1'
      SET @cSkipLottable04 = '1'
   END

   -- (james13) all skip lottable config turned on then skip lottable screen
   IF @cSkipLottable01 = '1' AND @cSkipLottable02 = '1' AND @cSkipLottable03 = '1' AND @cSkipLottable04 = '1'
      SET @cSkipLottable = '1'

   -- EventLog sign in
   EXEC RDT.rdt_STD_EventLog
    @cActionType = '1', -- Sign in function
    @cUserID     = @cUserName,
    @nMobileNo   = @nMobile,
    @nFunctionID = @nFunc,
    @cFacility   = @cFacility,
    @cStorerKey  = @cStorer,
    @nStep       = @nStep

   -- Enable all fields
   SET @cFieldAttr01 = ''
   SET @cFieldAttr02 = ''
   SET @cFieldAttr03 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr05 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr07 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr09 = ''
   SET @cFieldAttr10 = ''
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

   -- Prep next screen var
   SET @cOutField01 = '' -- ReceiptKey
   SET @cOutField02 = @cPOKeyDefaultValue -- POKey

   -- Set the entry point
   SET @nScn  = 1750
   SET @nStep = 1
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 1750. ASN, PO screen
 ASN    (field01, input)
 PO     (field02, input)
 EXTASN (field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      --to remove 'NOPO' as default to outfield02
      IF UPPER(@cInField02) <> 'NOPO'
      BEGIN
         SET @cPOKey = ''
         SET @cOutField02=''
      END

      -- Screen mapping
      SET @cReceiptKey = @cInField01
      SET @cPOKey = @cInField02
      SET @cRefNo = @cInField03

      -- Check ref no
      IF @cRefNo <> '' AND @cReceiptKey = ''
      BEGIN
         -- Get storer config
         DECLARE @cColumnName NVARCHAR(20)
         SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorer)

         IF @cColumnName = '' OR @cColumnName = '0'
         BEGIN
            SET @nErrNo = 64300
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Setup Ref Cfg
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
            GOTO Quit
         END

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)

            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 64297
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
               GOTO Quit
            END

            SET @cSQL =
               ' SELECT @cReceiptKey = ReceiptKey ' +
               ' FROM dbo.Receipt WITH (NOLOCK) ' +
               ' WHERE Facility = @cFacility ' +
                  ' AND Status <> ''9'' ' +
                  CASE WHEN @cDataType IN ('int', 'float')
                       THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                       ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
                  END +
                  CASE WHEN @cStorerGroup = ''
                       THEN ' AND StorerKey = @cStorerKey '
                       ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey) '
                  END +
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
            SET @cSQLParam =
               ' @nMobile      INT, ' +
               ' @cFacility    NVARCHAR(5),  ' +
               ' @cStorerGroup NVARCHAR(20), ' +
               ' @cStorerKey   NVARCHAR(15), ' +
               ' @cColumnName  NVARCHAR(20), ' +
               ' @cRefNo NVARCHAR(20), ' +
               ' @cReceiptKey  NVARCHAR(10) OUTPUT, ' +
               ' @nRowCount    INT          OUTPUT, ' +
               ' @nErrNo       INT          OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile,
               @cFacility,
               @cStorerGroup,
               @cStorer,
               @cColumnName,
               @cRefNo,
               @cReceiptKey OUTPUT,
               @nRowCount   OUTPUT,
               @nErrNo      OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

         -- Check RefNo in ASN
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 64298
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Quit
            END

            -- Check RefNo in ASN
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 64299
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
               EXEC rdt.rdtSetFocusField @nMobile, 3
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            -- Lookup field is SP
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cColumnName AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
                  ' @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerGroup, @cStorerKey, @cRefNo, @cReceiptKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
               SET @cSQLParam =
                  '@nMobile       INT,           ' +
                  '@nFunc         INT,           ' +
                  '@cLangCode     NVARCHAR( 3),  ' +
                  '@cFacility     NVARCHAR( 5),  ' +
                  '@cStorerGroup  NVARCHAR( 20), ' +
                  '@cStorerKey    NVARCHAR( 15), ' +
                  '@cRefNo        NVARCHAR( 20), ' +
                  '@cReceiptKey   NVARCHAR(10)  OUTPUT, ' +
                  '@nErrNo        INT           OUTPUT, ' +
                  '@cErrMsg       NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @cFacility, @cStorerGroup, @cStorer, @cRefNo, @cReceiptKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END

         SET @cOutField01 = @cReceiptKey
         SET @cOutField03 = @cRefNo
      END

      -- When both ASN and PO is blank
      IF @cReceiptKey = '' AND  @cPOkey = ''
      BEGIN
         SET @nErrNo = 64251
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64251 ', 'ASN or PO', 'Required'
         GOTO Step_1_Fail
      END

      IF @cReceiptKey = '' AND UPPER(@cPOKey) ='NOPO'
      BEGIN
         SET @nErrNo = 64252
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64252 ', 'ASN needed'
         GOTO Step_1_Fail
      END

      -- When both ASN and PO key in, check if the ASN and PO exists
      IF @cReceiptKey <> '' AND @cPOKey <> '' AND  UPPER(@cPOKey) <> 'NOPO'
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.Receipt R WITH (NOLOCK)
               JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            WHERE R.ReceiptKey = @cReceiptkey
               AND RD.POKey = @cPOKey)
         BEGIN
            SET @nErrNo = 64253
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64253 ', 'Invalid ASN/PO'
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Quit
         END
      END

       -- When only PO keyed-in (ASN left as blank)
      IF @cPOKey <> '' AND UPPER(@cPOKey) <> 'NOPO' AND @cReceiptkey  = ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey)
         BEGIN
            SET @nErrNo = 64254
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64254 ', 'PO not exists'
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
            GOTO Step_1_Fail
         END

         DECLARE @nCountReceipt int
         SET @nCountReceipt = 0

         -- Get ReceiptKey count
         SELECT @nCountReceipt = COUNT(DISTINCT Receiptkey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE POKey = @cPOKey
         GROUP BY POkey

         IF @nCountReceipt = 1
         BEGIN
            -- Get single ReceiptKey
            SELECT @cReceiptKey = ReceiptKey
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE POkey = @cPOKey
            GROUP BY ReceiptKey
         END
         ELSE IF @nCountReceipt > 1
         BEGIN
            SET @nErrNo = 64255
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64255 ', 'Multi ASN in PO'
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
            GOTO Step_1_Fail
         END
      END

      -- Check if receiptkey exists
      IF NOT EXISTS (SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey)
      BEGIN
         SET @nErrNo = 64256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
               SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64256 ', 'ASN not exists'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      -- Check diff facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Facility = @cFacility)
      BEGIN
         SET @nErrNo = 64257
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64257 ', 'Diff facility'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      -- Check diff storer
      IF NOT EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND Storerkey = @cStorer)
      BEGIN
         SET @nErrNo = 64258
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64258 ', 'Diff storer'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      -- Check for ASN closed by receipt.ASNStatus
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = '9' )
      BEGIN
         SET @nErrNo = 64259
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64259 ', 'ASN closed'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      -- Check for ASN cancelled
      IF EXISTS ( SELECT 1
         FROM dbo.Receipt WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptkey
            AND ASNStatus = 'CANC')
      BEGIN
         SET @nErrNo = 64260
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64260 ', 'ASN cancelled'
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey
         GOTO Step_1_Fail
      END

      -- When only ASN keyed-in (PO left as blank or NOPO): --retrieve single PO if there is
      IF @cReceiptKey <> '' AND (@cPOKey = '' OR UPPER(@cPOKey) = 'NOPO')
      BEGIN
         DECLARE @nCountPOKey int
         SET @nCountPOKey = 0

         --get pokey count
         SELECT @nCountPOKey = count(distinct POKey)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptkey
         GROUP BY Receiptkey

         IF @nCountPOKey = 1
         BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
            BEGIN
               --get single pokey
               SELECT @cPOKey = POKey
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptkey
               GROUP BY POkey
            END
         END
         ELSE IF @nCountPOKey > 1
         BEGIN
            --receive against blank PO
            IF EXISTS ( SELECT 1
                        FROM dbo.ReceiptDetail WITH (NOLOCK)
                        WHERE ReceiptKey = @cReceiptkey
                           AND (POKey IS NULL or POKey = ''))
            BEGIN
            IF UPPER(@cPOKey) <> 'NOPO'
               SET @cPOKey = ''
            END
            ELSE
            BEGIN
               IF UPPER(@cPOKey) <> 'NOPO'
               BEGIN
                  SET @nErrNo = 64261
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  SET @cErrMsg1 = @cErrMsg
                  SET @nErrNo = 0
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  IF @nErrNo = 1
                     SET @cErrMsg1 = ''

                  --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64261 ', 'PO needed'
                  SET @cOutField01 = @cReceiptKey
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- POKey
                  GOTO Quit
               END

            END
         END
      END

      -- Extended validate (yeekung05)
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_1_Fail
      END


      -- (james04)
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_1_Fail
      END

      SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN '1' ELSE '0' END

      -- Get RDT storer config 'ReceiveDefaultToLoc'
      SET @cLOC = rdt.RDTGetConfig( 0, 'ReceiveDefaultToLoc', @cStorer)
      IF @cLOC = '0' SET @cLOC = ''

      -- (cc03)
      IF @cSuggestedLocSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestedLocSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,    ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@cSuggestedLoc NVARCHAR( 10) OUTPUT, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_1_Fail

         IF @cSuggestedLoc <> ''
            SET @cLOC = @cSuggestedLoc
      END

      --prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cRefNo
      SET @cOutField04 = @cLOC

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog sign out
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorer,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReceiptkey = ''
      SET @cOutField01 = '' --ReceiptKey
      SET @cOutField02 = @cPOKey
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 1751. LOC screen
 ASN    (field01)
 PO     (field02)
 EXTASN (field03)
 LOC    (field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField04

      -- Check blank LOC
      IF @cLOC = '' OR @cLOC IS NULL
      BEGIN
         SET @nErrNo = 64262
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64262 ', 'LOC required'
         GOTO Step_2_Fail
      END
      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_2_Fail
            
            IF @nAfterStep = 3
            BEGIN
               SET @cTOID = ''
               SET @cAutoID = ''
               -- Auto generate ID
               IF @cAutoGenID <> ''
               BEGIN
                  EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                     ,@cAutoGenID
                     ,@cReceiptKey
                     ,@cPOKey
                     ,@cLOC
                     ,@cToID
                     ,@cOption
                     ,@cAutoID  OUTPUT
                     ,@nErrNo   OUTPUT
                     ,@cErrMsg  OUTPUT
                  IF @nErrNo <> 0
                     GOTO Step_2_Fail

                  SET @cToID = @cAutoID
               END

               -- Prepare next screen variable
               SET @cOutField01 = @cReceiptkey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = @cLOC
               SET @cOutField04 = @cTOID

               -- Go to next screen
               SET @nScn = @nScn + 1
               SET @nStep = @nStep + 1
               GOTO Quit
            END
         END
      END
      -- add loc prefix (yeekung01)
      IF @cLOCLookupSP = 1
      BEGIN
         EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility,
            @cLOC       OUTPUT,
            @nErrNo     OUTPUT,
            @cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail
      END

      -- Check invalid LOC
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC)
      BEGIN
         SET @nErrNo = 64263
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64263 ', 'LOC not found'
         GOTO Step_2_Fail
      END

      -- Check different facility
      IF NOT EXISTS ( SELECT 1
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND FACILITY = @cFacility)
      BEGIN
         SET @nErrNo = 64264
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64264 ', 'Diff facility'
         GOTO Step_2_Fail
      END

      -- (cc02)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_2_Fail
      END

      SET @cTOID = ''
      SET @cAutoID = ''
      SET @nAction = 3
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_2_Fail
            IF @nAfterStep <> 0
            BEGIN
               SET @nScn = @nAfterScn
               SET @nStep = @nAfterStep
               SET @cSKU = ''
               SET @cUOM = ''
               IF @cSkipLottable = '1' AND @nStep = 4
                  GOTO Step_4

               -- Skip lottable
               IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = '', @cLottable01 = ''
               IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = '', @cLottable02 = ''
               IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = '', @cLottable03 = ''
               IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = '', @dLottable04 = 0
               GOTO Quit
            END
         
         END
      END

      -- Auto generate ID
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
            ,@cAutoGenID
            ,@cReceiptKey
            ,@cPOKey
            ,@cLOC
            ,@cToID
            ,@cOption
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_2_Fail

         SET @cToID = @cAutoID
      END

      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cTOID

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' -- ReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = '' -- ExtASN

      IF @cRefNo <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Refno
      ELSE
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

      -- go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField04 = '' -- LOC
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 1752. ID screen
 ASN (field01)
 PO  (field02)
 LOC (field03)
 ID  (field04, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cIDBarcode  NVARCHAR( 60)
      
      -- Screen mapping
      SET @cTOID = @cInField04
      SET @cIDBarcode = @cInField04

      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'ID', @cIDBarcode) = 0
      BEGIN
         SET @nErrNo = 64295
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      -- Decode
      -- Standard decode
      IF @cDecodeSP = '1'
      BEGIN
         EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cIDBarcode,
            @cID     = @cTOID   OUTPUT,
            @nErrNo  = @nErrNo  OUTPUT,
            @cErrMsg = @cErrMsg OUTPUT,
            @cType   = 'ID'

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END
      ELSE
      BEGIN
         -- Label decoding
         IF @cDecodeLabelNo <> ''
         BEGIN
            SET @c_oFieled01 = @cTOID

            EXEC dbo.ispLabelNo_Decoding_Wrapper
                @c_SPName     = @cDecodeLabelNo
               ,@c_LabelNo    = @cIDBarcode
               ,@c_Storerkey  = @cStorer
               ,@c_ReceiptKey = ''
               ,@c_POKey      = ''
               ,@c_LangCode   = @cLangCode
               ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
               ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
               ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
               ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
               ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
               ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
               ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
               ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
               ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
               ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
               ,@b_Success    = @b_Success   OUTPUT
               ,@n_ErrNo      = @nErrNo      OUTPUT
               ,@c_ErrMsg     = @cErrMsg  OUTPUT

            IF ISNULL(@cErrMsg, '') <> ''
            BEGIN
               SET @cErrMsg1 = @cErrMsg
               SET @nErrNo = 0
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
               IF @nErrNo = 1
                  SET @cErrMsg1 = ''

             GOTO Step_3_Fail
            END

            SET @cTOID = @c_oFieled01
         END
      END

      -- (james05)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey    NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
       '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_3_Fail
      END

      -- Check ID exist in ASN
      IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckIDInASN', @cStorer) = 1 AND (@cTOID <> @cAutoID) -- AutoID don't need to check
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND RD.ToID = @cToID)
         BEGIN
            SET @nErrNo = 64266
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64266 ', 'ID not in ASN'
            GOTO Step_3_Fail
         END
      END

      -- Get storer config DisAllowDuplicateIdsOnRFRcpt
      DECLARE @cDisAllowDuplicateIdsOnRFRcpt NVARCHAR(1)
      SET @cDisAllowDuplicateIdsOnRFRcpt = ''
      EXECUTE dbo.nspGetRight
         NULL, -- Facility
         @cStorer,
         @cSKU,
         'DisAllowDuplicateIdsOnRFRcpt',
         @b_success                        OUTPUT,
         @cDisAllowDuplicateIdsOnRFRcpt    OUTPUT,
         @nErrNo                           OUTPUT,
         @cErrMsg        OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 64267
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64267 ', 'nspGetRight'
         GOTO Step_3_Fail
      END

      -- Check if duplicate TOID
      IF (@cDisAllowDuplicateIdsOnRFRcpt = '1') AND (@cTOID <> '' AND @cTOID IS NOT NULL)
      BEGIN
         -- check if TOLOC received before
         IF EXISTS ( SELECT LLI.ID
            FROM dbo.LotxLocxId LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
            WHERE LLI.ID = @cTOID
               AND LOC.Facility = @cFacility
               AND LLI.QTY > 0)
         BEGIN
            SET @nErrNo = 64268
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64268 ', 'Duplicate ID'
            GOTO Step_3_Fail
         END
      END

      DECLARE @cReceiveByPieceDefLottableByID NVARCHAR(1)
      SET @cReceiveByPieceDefLottableByID = rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceDefLottableByID', @cStorer)

      -- Reset lottables
      IF @cReceiveByPieceDefLottableByID = '0'
      BEGIN
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL
      END

      -- Retrieve lottables on ToID
      ELSE IF @cReceiveByPieceDefLottableByID = '1'
      BEGIN
         SET @cLottable01 = ''
         SET @cLottable02 = ''
         SET @cLottable03 = ''
         SET @dLottable04 = NULL

         SELECT TOP 1
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND POKey = CASE WHEN @cPOKey = '' OR @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
            AND ToID = @cToID
         ORDER BY ReceiptLineNumber
      END

      -- Retain lottable
      -- ELSE IF @ReceiveByPieceDefLottableByID = '2'

      -- Retrieve pre lottable values
      SET @nCount = 1
      WHILE @nCount <= 4
      BEGIN
         IF @nCount = 1 SET @cListName = 'Lottable01'
         IF @nCount = 2 SET @cListName = 'Lottable02'
         IF @nCount = 3 SET @cListName = 'Lottable03'
         IF @nCount = 4 SET @cListName = 'Lottable04'

         SET @cShort = ''
         SET @cStoredProd = ''
         SET @cLottableLabel = ''

         -- Get PRE store procedure
         SELECT TOP 1
            @cShort = C.Short,
            @cStoredProd = IsNULL( C.Long, ''),
            @cLottableLabel = S.SValue
         FROM dbo.CodeLkUp C WITH (NOLOCK)
            JOIN RDT.StorerConfig S WITH (NOLOCK)ON C.ListName = S.ConfigKey
         WHERE C.ListName = @cListName
            AND C.Code = S.SValue
            AND S.Storerkey = @cStorer -- NOTE: storer level
            AND (C.StorerKey = @cStorer OR C.StorerKey = '')
         ORDER BY C.StorerKey DESC

         -- Execute PRE store procedure
         IF @cShort = 'PRE' AND @cStoredProd <> ''
         BEGIN
            EXEC dbo.ispLottableRule_Wrapper
               @c_SPName            = @cStoredProd,
               @c_ListName          = @cListName,
               @c_Storerkey         = @cStorer,
               @c_Sku               = '',
               @c_LottableLabel     = @cLottableLabel,
               @c_Lottable01Value   = '',
               @c_Lottable02Value   = '',
               @c_Lottable03Value   = '',
               @dt_Lottable04Value  = '',
               @dt_Lottable05Value  = '',
               @c_Lottable01 = @cLottable01 OUTPUT,
               @c_Lottable02        = @cLottable02 OUTPUT,
               @c_Lottable03        = @cLottable03 OUTPUT,
               @dt_Lottable04       = @dLottable04 OUTPUT,
               @dt_Lottable05       = @dLottable05 OUTPUT,
               @b_Success           = @b_Success   OUTPUT,
               @n_Err               = @nErrNo      OUTPUT,
               @c_Errmsg            = @cErrMsg     OUTPUT,
               @c_Sourcekey         = @cReceiptkey,
              @c_Sourcetype        = 'rdtfnc_PieceReceivin' -- NVARCHAR(20) only

               IF ISNULL(@cErrMsg, '') <> ''
               BEGIN
                  SET @cErrMsg = @cErrMsg
                  GOTO Step_3_Fail
                  BREAK
               END
         END
         SET @nCount = @nCount + 1
      END
  
      -- Skip lottable
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = '', @cLottable01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = '', @cLottable02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = '', @cLottable03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = '', @dLottable04 = 0

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,         ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT 
            @cPalletType = PalletType
         FROM dbo.PalletTypeMaster WITH (NOLOCK)
         WHERE StorerKey = @cStorer
         AND Facility = @cFacility
         AND PalletTypeInUse = 'Y'

         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount > 1
         BEGIN
            SET @cFieldAttr01='1'
            SET @cOutField01 = ''
            -- Go to next screen
            SET @nScn = 6382
            SET @nStep = 99
            GOTO Quit
         END
         ELSE IF @nRowCount=1
         BEGIN
            UPDATE RDT.RDTMOBREC SET
            C_String1 = @cPalletType
            WHERE Mobile = @nMobile
         END
      END

      IF @cEnableAllLottables = '1'
      BEGIN
         -- Init next screen var
         SET @cOutField01 = @cTOID
         SET @cOutField03 = '' -- SKUDesc1
         SET @cOutField04 = '' -- SKUDesc2
         SET @cMax = ''
         SET @nScn  = 4033
         SET @nStep = 12
         GOTO Quit
      END

      -- Get ToIDQTY
      SELECT @nToIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM   dbo.Receiptdetail WITH (NOLOCK)
      WHERE  receiptkey = @cReceiptkey
      AND    toloc = @cLOC
      AND    toid = @cTOID
      AND    Storerkey = @cStorer

      -- Prep next screen var
      SET @cLottable01 = IsNULL( @cLottable01, '')
      SET @cLottable02 = IsNULL( @cLottable02, '')
      SET @cLottable03 = IsNULL( @cLottable03, '')
      --SET @dLottable04 = IsNULL( @dLottable04, 0)
      SET @cSKU = ''
      SET @cUOM = ''

      SET @cOutField01 = @cLottable01
      SET @cOutField02 = @cLottable02
      SET @cOutField03 = @cLottable03
      -- SET @cOutField04 = CASE WHEN @dLottable04 IS NULL THEN rdt.rdtFormatDate( @dLottable04) END
      SET @cOutField04 = rdt.rdtFormatDate( @dLottable04)

      EXEC rdt.rdtSetFocusField @nMobile, 1 --Lottable01

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- (james13)
      IF @cSkipLottable = '1'
         GOTO Step_4
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cRefNo

      SET @cLOC = rdt.RDTGetConfig( 0, 'ReceiveDefaultToLoc', @cStorer)
      IF @cLOC = '0' SET @cLOC = ''

      -- (cc03)
      IF @cSuggestedLocSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cSuggestedLocSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@cSuggestedLoc NVARCHAR( 10) OUTPUT, ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @cSuggestedLoc OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_3_Fail

         IF @cSuggestedLoc <> ''
            SET @cLOC = @cSuggestedLoc
      END

      SET @cOutField04 = @cLoc --'' -- LOC -- (ChewKP06)

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cTOID = ''
      SET @cOutField04 = '' -- TOID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Screen = 1753. Lottable 1 to 4
 Lottable01: (field01, input)
 Lottable02: (field02, input)
 Lottable03: (field03, input)
 Lottable04: (field04, input)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1      -- ENTER
   BEGIN
      --Screen Mapping
      SET @cTempLottable01 = @cInField01
      SET @cTempLottable02 = @cInField02
      SET @cTempLottable03 = @cInField03
      SET @cTempLottable04 = @cInField04

      -- Decode lottable  --(cc02)
      IF @cDecodeLottableSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeLottableSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeLottableSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cToLOC, @cToID, ' +
               ' @cLottable01Value, @cLottable02Value, @cLottable03Value, @cLottable04Value, ' +
               ' @cTempLottable01 OUTPUT, @cTempLottable02 OUTPUT, ' +
               ' @cTempLottable03 OUTPUT, @cTempLottable04 OUTPUT, ' +
               ' @nErrNo          OUTPUT, @cErrMsg         OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60),' +
               ' @cToLOC       NVARCHAR( 10), ' +
               ' @cToID        NVARCHAR( 18), ' +
               ' @cLottable01Value  NVARCHAR( 20), ' +
               ' @cLottable02Value  NVARCHAR( 20), ' +
               ' @cLottable03Value  NVARCHAR( 20), ' +
               ' @cLottable04Value  NVARCHAR( 16), ' +
               ' @cTempLottable01   NVARCHAR( 18)  OUTPUT, ' +
               ' @cTempLottable02   NVARCHAR( 18)  OUTPUT, ' +
               ' @cTempLottable03   NVARCHAR( 18)  OUTPUT, ' +
               ' @cTempLottable04   NVARCHAR( 16)  OUTPUT, ' +
               ' @nErrNo            INT            OUTPUT, ' +
               ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cBarcode,
               @cLOC, @cToID,
               @cTempLottable01, @cTempLottable02, @cTempLottable03, @cTempLottable04,
               @cTempLottable01 OUTPUT, @cTempLottable02 OUTPUT,
               @cTempLottable03 OUTPUT, @cTempLottable04 OUTPUT,
               @nErrNo      OUTPUT, @cErrMsg     OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_4_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'Lottable01', @cTempLottable01) = 0
      BEGIN
         SET @nErrNo = 183451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Step_4_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'Lottable02', @cTempLottable02) = 0
      BEGIN
         SET @nErrNo = 183452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Step_4_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'Lottable03', @cTempLottable03) = 0
      BEGIN
         SET @nErrNo = 183453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Step_4_Fail
      END

      IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'Lottable04', @cTempLottable04) = 0
      BEGIN
         SET @nErrNo = 183454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
         GOTO Step_4_Fail
      END

      -- Check for date validation for lottable04
      IF @cTempLottable04 <> '' AND rdt.rdtIsValidDate( @cTempLottable04) = 0
      BEGIN
         SET @nErrNo = 64269
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64269 ', 'Invalid Date'
         SET @cOutField04 = @cTempLottable04
         EXEC rdt.rdtSetFocusField @nMobile, 4 -- Lottable04
         GOTO Step_4_Fail
      END

      -- Get QTY statistic (for previous scanned SKU)
      SELECT
         @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
         @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      --AND   POKey      = @cPOKey
      AND   SKU        = @cSKU
      AND   ToID       = @cToID
      AND   ToLoc      = @cLoc
      AND   Storerkey  = @cStorer

      -- Get SKU label info
      SET @cSKULabel = ''
      SELECT
         @cDataWindow = DataWindow,
         @cTargetDB = TargetDB
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   ReportType = 'SKULABEL'
      AND  (Facility = @cFacility OR Facility = '')   -- (james10)
      AND  (Function_ID = @nFunc OR Function_ID = 0)
      ORDER BY Facility DESC, Function_ID DESC


      IF @@ROWCOUNT <> 0
      BEGIN
         -- Check login printer
         IF @cPrinter = ''
         BEGIN
              SET @nErrNo = 64270
              SET @cErrMsg = rdt.rdtgetmessage( 64270, @cLangCode, 'DSP') --NoLoginPrinter
              GOTO Step_4_Fail
         END

         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 64271
            SET @cErrMsg = rdt.rdtgetmessage( 64271, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_4_Fail
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 64272
            SET @cErrMsg = rdt.rdtgetmessage( 64272, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_4_Fail
         END

         SET @cSKULabel = '1'
      END

      -- (james09)
      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         -- (james20)
         DECLARE @dTempLottable04   DATETIME
         SET @dTempLottable04 = rdt.rdtConvertToDate(@cTempLottable04)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID       NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY     INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @cSKU, 0,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_4_Fail
      END

      -- Disable and default QTY field
      IF rdt.RDTGetConfig( 0, 'ReceiveByPieceDisableQTYField', @cStorer) = '1'
      BEGIN
         SET @cFieldAttr05 = 'O' -- QTY
         SET @cDefaultPieceRecvQTY = '1'
      END
      ELSE
      BEGIN
         -- Get default QTY
         SET @cDefaultPieceRecvQTY = rdt.RDTGetConfig( 0, 'DefaultPieceRecvQTY', @cStorer)
         IF @cDefaultPieceRecvQTY = '0'
            SET @cDefaultPieceRecvQTY = ''
      END

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nBeforeReceivedQty OUTPUT
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nQtyExpected OUTPUT
      END

      -- Enable field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

      -- Extended info
      SET @cExtendedInfo = ''
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            IF OBJECT_SCHEMA_NAME( OBJECT_ID( @cExtendedInfoSP)) = 'dbo'
            BEGIN
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
                  ' @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cPOKey        NVARCHAR( 10), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cToID         NVARCHAR( 18), ' +
                  '@cLottable01   NVARCHAR( 18), ' +
                  '@cLottable02   NVARCHAR( 18), ' +
                  '@cLottable03   NVARCHAR( 18), ' +
                  '@dLottable04   DATETIME,  ' +
                  '@cStorer       NVARCHAR( 15), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT
            END
            ELSE
            BEGIN 
                SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
                  ' @cReceiptKey, @cPOKey, @cRefNo, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, ' + 
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
                SET @cSQLParam =
                  ' @nMobile         INT,                    ' +  
                  ' @nFunc           INT,                    ' + 
                  ' @cLangCode       NVARCHAR( 3),           ' + 
                  ' @nStep           INT,                    ' + 
                  ' @nAfterStep      INT,                    ' + 
                  ' @nInputKey       INT,                    ' + 
                  ' @cFacility       NVARCHAR( 5),           ' + 
                  ' @cStorerKey      NVARCHAR( 15),          ' + 
                  ' @cReceiptKey     NVARCHAR( 10),          ' + 
                  ' @cPOKey          NVARCHAR( 10),          ' + 
                  ' @cRefNo          NVARCHAR( 20),          ' + 
                  ' @cToLOC          NVARCHAR( 10),          ' + 
                  ' @cToID           NVARCHAR( 18),          ' + 
                  ' @cLottable01     NVARCHAR( 18),          ' + 
                  ' @cLottable02     NVARCHAR( 18),          ' + 
                  ' @cLottable03     NVARCHAR( 18),          ' + 
                  ' @dLottable04     DATETIME,               ' + 
                  ' @cSKU            NVARCHAR( 20),          ' + 
                  ' @nQTY            INT,                    ' + 
                  ' @tVar            VariableTable READONLY, ' + 
                  ' @cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' + 
                  ' @nErrNo          INT           OUTPUT,   ' + 
                  ' @cErrMsg         NVARCHAR( 20) OUTPUT    ' 

                EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, 5, @nInputKey, @cFacility, @cStorer, 
                  @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID, @cTempLottable01, @cTempLottable02, @cTempLottable03, @dTempLottable04, @cSKU, @nQTY, @tVar, 
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            END
         END
      END

      SET @cSKUValidated = '0'

      -- Prepare next screen variable
      SET @cPrevBarcode = ''
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' -- sku
      SET @cOutField03 = '' -- sku desc1
      SET @cOutField04 = '' -- sku desc2
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
      SET @cOutField11 = @cSKU -- last SKU
      SET @cOutField12 = @cUOM -- last UOM
      SET @cOutField15 = @cExtendedInfo
      
      SET @cInField05 = @cDefaultPieceRecvQTY
      
      SET @cBarcode = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc
   BEGIN
      -- Check if pallet label setup
      IF EXISTS( SELECT 1
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ReportType IN ('PostRecv', 'PalletLBL')
            AND Function_ID IN (0, @nFunc)
            AND Facility IN ('', @cFacility))
      BEGIN
         -- Retain lottables
         SET @cTempLottable01 = @cOutField01
         SET @cTempLottable02 = @cOutField02
         SET @cTempLottable03 = @cOutField03
         SET @cTempLottable04 = @cOutField04

         -- Prepare next screen var
         SET @cOutField01 = '' -- Option

         -- Go message screen
         SET @nScn = @nScn + 2
         SET @nStep = @nStep + 2
      END

       -- Close pallet  
      ELSE IF @cClosePallet = '1'  
      BEGIN  
       --some condition no need close pallet  --(cc01)  
       IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cClosePalletSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cClosePalletSP) +  
               ' @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cClosePalletOut OUTPUT'  
            SET @cSQLParam =  
               '@cReceiptKey   NVARCHAR( 10), ' +  
               '@cPOKey        NVARCHAR( 10), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cToID         NVARCHAR( 18), ' +  
               '@cLottable01   NVARCHAR( 18), ' +  
               '@cLottable02   NVARCHAR( 18), ' +  
               '@cLottable03   NVARCHAR( 18), ' +  
               '@dLottable04   DATETIME,  ' +  
               '@cStorer       NVARCHAR( 15), ' +  
               '@cSKU          NVARCHAR( 20), ' +  
               '@cClosePalletOut NVARCHAR( 1) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cClosePalletOut OUTPUT  
                 
             IF @cClosePalletOut = '1'  
             BEGIN  
                 -- Retain lottables  
               SET @cTempLottable01 = @cOutField01  
               SET @cTempLottable02 = @cOutField02  
               SET @cTempLottable03 = @cOutField03  
               SET @cTempLottable04 = @cOutField04  
  
               -- Prepare next screen var  
               SET @cOutField01 = '' -- Option  
  
               -- Go message screen  
               SET @nScn = @nScn + 6  
               SET @nStep = @nStep + 6  
             END  
         END  
         ELSE IF @cClosePallet = '1'  
         BEGIN  
          -- Retain lottables  
            SET @cTempLottable01 = @cOutField01  
            SET @cTempLottable02 = @cOutField02  
            SET @cTempLottable03 = @cOutField03  
            SET @cTempLottable04 = @cOutField04  
  
            -- Prepare next screen var  
            SET @cOutField01 = '' -- Option  
  
            -- Go message screen  
            SET @nScn = @nScn + 6  
            SET @nStep = @nStep + 6  
         END  
      END  
      ELSE IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT 
            @cPalletType = PalletType
         FROM dbo.PalletTypeMaster WITH (NOLOCK)
         WHERE StorerKey = @cStorer
         AND Facility = @cFacility
         AND PalletTypeInUse = 'Y'

         IF @@ROWCOUNT > 1
         BEGIN
            SET @cFieldAttr01='1'
            SET @cOutField01 = ''
            SET @nScn = 6382
            SET @nStep = 99
            GOTO Quit
         END
         ELSE
         BEGIN
            --Skip ID Screen
            SET @cExtendedScreenSP =  ISNULL(rdt.RDTGetConfig( @nFunc, '1580ExtendedScreenSP', @cStorer), '')
            SET @nAction = 3
            IF @cExtendedScreenSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
               BEGIN
                  EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                     @cExtendedScreenSP,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                     @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                     @nAction, 
                     @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                     @nErrNo   OUTPUT, 
                     @cErrMsg  OUTPUT
                  
                  IF @nErrNo <> 0
                     GOTO Quit
                  IF @nAfterStep <> 0
                  BEGIN
                     SET @nScn = @nAfterScn
                     SET @nStep = @nAfterStep
                     GOTO Quit
                  END
               END
            END
            -- Auto generate ID
            IF @cAutoGenID <> ''
            BEGIN
               EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                  ,@cAutoGenID
                  ,@cReceiptKey
                  ,@cPOKey
                  ,@cLOC
                  ,@cToID
                  ,@cOption
                  ,@cAutoID  OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Step_4_Fail

               SET @cToID = @cAutoID
            END
            ELSE
            BEGIN
               SET @cToID = ''
               SET @cAutoID = ''
            END

            -- Prepare prev screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = @cLOC
            SET @cOutField04 = @cToID

            -- Go to previous screen
            SET @nScn = @nScn - 1
            SET @nStep = @nStep - 1
         END
      END
      ELSE
      BEGIN
         SET @nAction = 3
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
            BEGIN
               EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                  @cExtendedScreenSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                  @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                  @nAction, 
                  @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                  @nErrNo   OUTPUT, 
                  @cErrMsg  OUTPUT
               
               IF @nErrNo <> 0
                  GOTO Quit
               IF @nAfterStep <> 0
               BEGIN
                  SET @nScn = @nAfterScn
                  SET @nStep = @nAfterStep
                  GOTO Quit
               END
            END
         END
         -- Auto generate ID
         IF @cAutoGenID <> ''
         BEGIN
            EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
               ,@cAutoGenID
               ,@cReceiptKey
               ,@cPOKey
               ,@cLOC
               ,@cToID
               ,@cOption
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Step_4_Fail

            SET @cToID = @cAutoID
         END
         ELSE
         BEGIN
            SET @cToID = ''
            SET @cAutoID = ''
         END

         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cToID

         -- Go to previous screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, 4, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_4_Fail
      END

      -- Enable field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
   END


   
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData

         IF @cExtScnSP = 'rdt_1581ExtScn01'
         BEGIN
            INSERT INTO @tExtScnData (Variable, Value) VALUES 	
            ('@cTempLottable02',     @cTempLottable02)

            SET @nAction = 3
         END        
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_4_Fail
         
         IF @cExtScnSP = 'rdt_1581ExtScn01'
         BEGIN
            SET @cTempLottable01 = @cUDF01
         END
      END
   End
   GOTO Quit

   Step_4_Fail:
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 1754. SKU screen
 TO ID     (field01)
 SKU       (field02, input)
 SKU       (field11)
 Desc1     (field03)
 Desc2     (field04)
 QTY REC   (field06)
 QTY       (field05, input)
 QTY ON ID (field10)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField05 -- QTY
      SET @cBarcode = SUBSTRING( @cBarcode, 1, 2000)
      SET @cSKU = @cBarcode -- SKU

      -- Validate SKU
      IF ISNULL( @cSKU,'') = ''
      BEGIN
         SET @nErrNo = 64273
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64273 ', 'SKU Required'
         EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
         GOTO Quit
      END

      IF @cSKUValidated = '0'
      BEGIN
         -- Decode
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            SET @nDecodeQTY = 0
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nDecodeQTY    OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UPC'

             -- (james15)
              IF @nDecodeQTY > 0
                 SET @cQTY = @nDecodeQTY
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')  
            BEGIN  
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +  
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cID, @cBarcode, ' +  
                  ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +  
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @cSerialNoCapture OUTPUT, ' +  
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'  
               SET @cSQLParam =  
                  ' @nMobile           INT,           ' +  
                  ' @nFunc             INT,           ' +  
                  ' @cLangCode         NVARCHAR( 3),  ' +  
                  ' @nStep             INT,           ' +  
                  ' @nInputKey         INT,           ' +  
                  ' @cStorerKey        NVARCHAR( 15), ' +  
                  ' @cReceiptKey       NVARCHAR( 10), ' +  
                  ' @cPOKey            NVARCHAR( 10), ' +  
                  ' @cLOC              NVARCHAR( 10), ' +  
                  ' @cID               NVARCHAR( 18), ' +
                  ' @cBarcode          NVARCHAR( MAX), ' +  
                  ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +  
                  ' @nQTY              INT            OUTPUT, ' +  
                  ' @cLottable01       NVARCHAR( 18)  OUTPUT, ' +  
                  ' @cLottable02       NVARCHAR( 18)  OUTPUT, ' +  
                  ' @cLottable03       NVARCHAR( 18)  OUTPUT, ' +  
                  ' @dLottable04       DATETIME       OUTPUT, ' +  
                  ' @cSerialNoCapture  NVARCHAR(1)    OUTPUT, ' +
                  ' @nErrNo            INT            OUTPUT, ' +  
                  ' @cErrMsg           NVARCHAR( 20)  OUTPUT'  
  
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cTOID, @cBarcode,  
                  @cSKU        OUTPUT, @nQTY        OUTPUT,  
                  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @cSerialNoCapture OUTPUT,  
                  @nErrNo      OUTPUT, @cErrMsg     OUTPUT

               IF @nErrNo <> 0  
                  GOTO Step_5_Fail_SKU  

              IF @nQTY > 0
                 SET @cQTY = CAST( @nQTY AS NVARCHAR( 5))

               SET @cTempLottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE @cTempLottable01 END
               SET @cTempLottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE @cTempLottable02 END
               SET @cTempLottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE @cTempLottable03 END
               SET @cTempLottable04 = CASE WHEN ISNULL( @dLottable04, '') <> '' THEN rdt.RDTFORMATDATE(@dLottable04) 
                                      ELSE @cTempLottable04 END   -- (james30)
            END  
            ELSE
            BEGIN
               -- Label decoding
               IF @cDecodeLabelNo <> ''
               BEGIN
                  SET @c_oFieled01 = @cSKU
                  SET @c_oFieled03 = @cTempLottable06
                  SET @c_oFieled05 = @cQTY
                  SET @c_oFieled07 = @cTempLottable01
                  SET @c_oFieled08 = @cTempLottable02
                  SET @c_oFieled09 = @cTempLottable03
                  SET @c_oFieled10 = @cTempLottable04

                  EXEC dbo.ispLabelNo_Decoding_Wrapper
                      @c_SPName     = @cDecodeLabelNo
                     ,@c_LabelNo    = @cBarcode --(yeekung01)
                     ,@c_Storerkey  = @cStorer
                     ,@c_ReceiptKey = @cReceiptkey
                     ,@c_POKey      = ''
                     ,@c_LangCode   = @cLangCode
                     ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
                     ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
                     ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
                     ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
                     ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
                     ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
                     ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
                     ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
                     ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
                     ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
                     ,@b_Success    = @b_Success   OUTPUT
                     ,@n_ErrNo      = @nErrNo     OUTPUT
                     ,@c_ErrMsg     = @cErrMsg     OUTPUT

                  IF ISNULL(@cErrMsg, '') <> ''
                  BEGIN
                     SET @cErrMsg1 = @cErrMsg
                     SET @nErrNo = 0
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                     IF @nErrNo = 1
                        SET @cErrMsg1 = ''

                     GOTO Step_5_Fail_SKU
                  END

                  SET @cSKU = @c_oFieled01
                  SET @cSerialNo = @c_oFieled02 -- (james19)
                  SET @cTempLottable06 = @c_oFieled03
                  SET @cQTY = @c_oFieled05
                  SET @cTempLottable01 = @c_oFieled07
                  SET @cTempLottable02 = @c_oFieled08
                  SET @cTempLottable03 = @c_oFieled09
                  SET @cTempLottable04 = @c_oFieled10
               END
            END
         END
      END

      -- Get SKU/UPC
      DECLARE @nSKUCnt INT
      DECLARE @cSKUCode NVARCHAR(20)
      SET @nSKUCnt = 0

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorer
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 64274
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64274 ', 'Invalid SKU'
         GOTO Step_5_Fail_SKU
      END

      IF @nSKUCnt = 1
      BEGIN
         --SET @cSKU = @cSKUCode
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorer
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
            ,@nUPCQty     = @nUPCQty       OUTPUT
         
         IF @nUPCQty > 0
            SET @cQTY = @nUPCQty
      END      
         
      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            DECLARE @cDocType NVARCHAR( 30) = ''
            DECLARE @cDocNo   NVARCHAR( 20) = ''
            
            IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInASN', @cStorer) = '1' OR -- 1=On,  means check SKU in ASN
               rdt.RDTGetConfig( @nFunc, 'SkipCheckingSKUNotInASN', @cStorer) = '0'        -- 0=Off, means check SKU in ASN
            BEGIN
               SET @cDocType = 'ASN'
               SET @cDocNo = @cReceiptKey
            END
            
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorer,
               @cSKU     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               @cDocType, 
               @cDocNo  

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nScn = 3570
               SET @nStep = @nStep + 3
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 64276
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64276 ', 'Multi SKU barcode'
            GOTO Step_5_Fail_SKU
         END
      END

      -- Validate SKU in PO
      IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInPO', @cStorer) = '1' AND @cPOKey <> '' AND @cPOKey <> 'NOPO'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail  WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU
               AND POKey = @cPOKey
               AND Receiptkey = @cReceiptKey)
         BEGIN
            SET @nErrNo = 64277
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64277 ', 'SKU Not in PO'
            GOTO Step_5_Fail_SKU
         END
      END

      -- Validate SKU in ASN
      IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInASN', @cStorer) = '1'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU
               AND Receiptkey = @cReceiptKey)
         BEGIN
            SET @nErrNo = 64278
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64278 ', 'SKU Not in ASN'
            GOTO Step_5_Fail_SKU
         END
      END

      -- Get SKU info
      DECLARE @cPackKey NVARCHAR(10)
      SELECT
         @cSKUDesc = 
            CASE WHEN @cDispStyleColorSize = '0'
                 THEN ISNULL( DescR, '')
                 ELSE CAST( Style AS NCHAR(20)) +
                      CAST( Color AS NCHAR(10)) +
                      CAST( Size  AS NCHAR(10))
            END,
         @cPackkey = PackKey,
         @cLottableLabel01 = IsNULL(Lottable01Label, ''),
         @cLottableLabel02 = IsNULL(Lottable02Label, ''),
         @cLottableLabel03 = IsNULL(Lottable03Label, ''),
         @cLottableLabel04 = IsNULL(Lottable04Label, '')
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
         AND SKU = @cSKU

      -- Get UOM
      SELECT @cUOM = PACKUOM3
      FROM dbo.Pack WITH (NOLOCK)
      WHERE Packkey = @cPackkey

      -- Retain original value for lottable01-04
      SET @cLottable01 = @cTempLottable01
      SET @cLottable02 = @cTempLottable02
      SET @cLottable03 = @cTempLottable03
      SET @dLottable04 = CASE WHEN @cTempLottable04 = '' THEN NULL ELSE rdt.rdtConvertToDate( @cTempLottable04) END

      DECLARE @cPostLottable01 NVARCHAR( 18)
      DECLARE @cPostLottable02 NVARCHAR( 18)
      DECLARE @cPostLottable03 NVARCHAR( 18)
      DECLARE @dPostLottable04 DATETIME
      DECLARE @dPostLottable05 DATETIME

      SET @cPostLottable01 = @cLottable01
      SET @cPostLottable02 = @cLottable02
      SET @cPostLottable03 = @cLottable03
      SET @dPostLottable04 = @dLottable04
      SET @nCount = 1

      -- Loop lottable1...4
      WHILE @nCount <= 4
      BEGIN
         IF @nCount = 1 SELECT @cListName = 'Lottable01', @cLottableLabel = @cLottableLabel01
         IF @nCount = 2 SELECT @cListName = 'Lottable02', @cLottableLabel = @cLottableLabel02
         IF @nCount = 3 SELECT @cListName = 'Lottable03', @cLottableLabel = @cLottableLabel03
         IF @nCount = 4 SELECT @cListName = 'Lottable04', @cLottableLabel = @cLottableLabel04

         -- Get POST store procedure
         SET @cShort = ''
         SET @cStoredProd = ''
         SELECT TOP 1
            @cShort = ISNULL( RTRIM( Short), ''),
            @cStoredProd = IsNULL( RTRIM( Long), '')
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE ListName = @cListName
            AND Code = @cLottableLabel
            AND Short = 'POST'
            AND (StorerKey = @cStorer OR StorerKey = '')
         ORDER BY StorerKey DESC

         -- Exec POST store procedure
         IF @cShort = 'POST' AND @cStoredProd <> ''
         BEGIN
            EXEC dbo.ispLottableRule_Wrapper
               @c_SPName            = @cStoredProd,
               @c_ListName          = @cListName,
               @c_Storerkey         = @cStorer,
               @c_Sku               = @cSKU,
               @c_LottableLabel     = @cLottableLabel,
               @c_Lottable01Value   = @cLottable01,
               @c_Lottable02Value   = @cLottable02,
               @c_Lottable03Value   = @cLottable03,
               @dt_Lottable04Value  = @dLottable04,
               @dt_Lottable05Value  = @dLottable05,
               @c_Lottable01        = @cPostLottable01 OUTPUT,
               @c_Lottable02        = @cPostLottable02 OUTPUT,
               @c_Lottable03        = @cPostLottable03 OUTPUT,
               @dt_Lottable04       = @dPostLottable04 OUTPUT,
               @dt_Lottable05       = @dPostLottable05 OUTPUT,
               @b_Success           = @b_Success   OUTPUT,
               @n_Err               = @nErrNo      OUTPUT,
               @c_Errmsg            = @cErrMsg     OUTPUT,
               @c_Sourcekey         = @cReceiptKey, --(ung02)
               @c_Sourcetype        = 'rdtfnc_PieceReceiving'

            IF @cErrMsg <> ''
               GOTO Step_5_Fail_SKU
         END
         SET @nCount = @nCount + 1
      END
      SET @cLottable01 = IsNULL( @cPostLottable01, '')
      SET @cLottable02 = IsNULL( @cPostLottable02, '')
      SET @cLottable03 = IsNULL( @cPostLottable03, '')
      SET @dLottable04 = @dPostLottable04

      -- Skip lottable
      IF @cSkipLottable01 = '1' SET @cLottable01 = ''
      IF @cSkipLottable02 = '1' SET @cLottable02 = ''
      IF @cSkipLottable03 = '1' SET @cLottable03 = ''
      IF @cSkipLottable04 = '1' SET @dLottable04 = 0

      -- Validate lottable01
      IF @cSkipLottable01 <> '1' AND (@cLottableLabel01 <> '' AND @cLottable01 = '')
      BEGIN
         SET @nErrNo = 64279
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64279 ', 'Lottable01 Required'
         GOTO Step_5_Fail_SKU
      END

      -- Validate lottable02
      IF @cSkipLottable02 <> '1' AND (@cLottableLabel02 <> '' AND @cLottable02 = '')
      BEGIN
         SET @nErrNo = 64280
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64280 ', 'Lottable02 Required'
         GOTO Step_5_Fail_SKU
      END

      -- Validate lottable03
      IF @cSkipLottable03 <> '1' AND (@cLottableLabel03 <> '' AND @cLottable03 = '')
      BEGIN
         SET @nErrNo = 64281
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64281 ', 'Lottable03 Required'
         GOTO Step_5_Fail_SKU
      END

      -- Validate lottable04
      IF @cSkipLottable04 <> '1' AND (@cLottableLabel04 <> '' AND @dLottable04 IS NULL)
      BEGIN
         SET @nErrNo = 64282
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64282 ', 'Lottable04 Required'
         GOTO Step_5_Fail_SKU
      END

      -- Get SKU default UOM
      DECLARE @cSKUDefaultUOM NVARCHAR( 10)
      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)
      IF @cSKUDefaultUOM = '0'
         SET @cSKUDefaultUOM = ''

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND @cSKUDefaultUOM = ''
      BEGIN
         SET @nErrNo = 64283
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64283 ', 'NEED SKUDEFUOM'
         GOTO Step_5_Fail_SKU
      END

      -- Check SKU default UOM in pack key
      IF @cSKUDefaultUOM <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.Pack P WITH (NOLOCK)
            WHERE PackKey = @cPackKey
               AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 64284
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64284 ', 'INV SKUDEFUOM'
            GOTO Step_5_Fail_SKU
         END
         SET @cUOM = @cSKUDefaultUOM

         -- Get UOM divider
         SET @nUOM_Div = 0
         SELECT @nUOM_Div =
         CASE
               WHEN @cSKUDefaultUOM = PackUOM1 THEN CaseCnt
               WHEN @cSKUDefaultUOM = PackUOM2 THEN InnerPack
               WHEN @cSKUDefaultUOM = PackUOM3 THEN QTY
               WHEN @cSKUDefaultUOM = PackUOM4 THEN Pallet
               WHEN @cSKUDefaultUOM = PackUOM5 THEN Cube
               WHEN @cSKUDefaultUOM = PackUOM6 THEN GrossWgt
               WHEN @cSKUDefaultUOM = PackUOM7 THEN NetWgt
               WHEN @cSKUDefaultUOM = PackUOM8 THEN OtherUnit1
               WHEN @cSKUDefaultUOM = PackUOM9 THEN OtherUnit2
            END
         FROM dbo.Pack P WITH (NOLOCK)
         WHERE PackKey = @cPackKey

         IF @nUOM_Div = 0
            SET @nUOM_Div = 1
      END
      ELSE
         SET @nUOM_Div = 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            IF OBJECT_SCHEMA_NAME( OBJECT_ID( @cExtendedInfoSP)) = 'dbo'
            BEGIN 
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
                  ' @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cPOKey        NVARCHAR( 10), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cToID         NVARCHAR( 18), ' +
                  '@cLottable01   NVARCHAR( 18), ' +
                  '@cLottable02   NVARCHAR( 18), ' +
                  '@cLottable03   NVARCHAR( 18), ' +
                  '@dLottable04   DATETIME,  ' +
                  '@cStorer       NVARCHAR( 15), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT
            END
         END
      END

      -- Verify SKU
      IF @cVerifySKU <> ''
      BEGIN
         EXEC rdt.rdt_VerifySKU @nMobile, @nFunc, @cLangCode, @cStorer, @cSKU, 'CHECK',
            @cWeight        OUTPUT,
            @cCube          OUTPUT,
            @cLength        OUTPUT,
            @cWidth         OUTPUT,
            @cHeight        OUTPUT,
            @cInnerPack     OUTPUT,
            @cCaseCount     OUTPUT,
            @cPalletCount   OUTPUT,
            @nErrNo         OUTPUT,
            @cErrMsg        OUTPUT,
            @cVerifySKUInfo OUTPUT

         IF @nErrNo <> 0
         BEGIN
            -- Enable field
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Info'   AND Short = '1') SET @cFieldAttr12 = '' ELSE SET @cFieldAttr12 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Weight' AND Short = '1') SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Cube'   AND Short = '1') SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Length' AND Short = '1') SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Width'  AND Short = '1') SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Height' AND Short = '1') SET @cFieldAttr08 = '' ELSE SET @cFieldAttr08 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Inner'  AND Short = '1') SET @cFieldAttr09 = '' ELSE SET @cFieldAttr09 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Case'   AND Short = '1') SET @cFieldAttr10 = '' ELSE SET @cFieldAttr10 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Pallet' AND Short = '1') SET @cFieldAttr11 = '' ELSE SET @cFieldAttr11 = 'O'

            -- Prepare next screen var
            SET @cOutField01 = @cSKU
            SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
            SET @cOutField04 = @cWeight
            SET @cOutField05 = @cCube
            SET @cOutField06 = @cLength
            SET @cOutField07 = @cWidth
            SET @cOutField08 = @cHeight
            SET @cOutField09 = @cInnerPack
            SET @cOutField10 = @cCaseCount
            SET @cOutField11 = @cPalletCount
            SET @cOutField12 = @cVerifySKUInfo

            -- Go to verify SKU screen
            SET @nScn = 3950 -- @nScn + 2
            SET @nStep = @nStep + 2

            GOTO Quit
         END
      END

      SET @cSKUValidated = '1'

      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField11 = @cSKU
      SET @cOutField12 = @cUOM
      SET @cOutField15 = @cExtendedInfo

      SET @cBarcode = @cSKU
      
      -- Validate blank QTY
      IF @cQty = '' OR @cQty IS NULL
      BEGIN
         -- Serial No
         IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
         BEGIN
            EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
               @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
               @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
               @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

            IF @nErrNo <> 0
               GOTO Quit

            IF @nMoreSNO = 1
            BEGIN
               SET @cMax = ''
               -- Go to Serial No screen
               SET @nFromScn = @nScn
               SET @nScn = 4831
               SET @nStep = @nStep + 4

               GOTO Step_5_Quit
            END
         END

         -- EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64273 ', 'QTY Required'
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_5_Quit
      END

      -- Validate QTY
      IF rdt.rdtIsValidQty( @cQty, 21) = 0
      BEGIN
         SET @nErrNo = 64285
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64285 ', 'Invalid QTY'
         GOTO Step_5_Fail_QTY
      END

      -- Check if max no of decimal is 6
      -- IF master.dbo.RegExIsMatch('^\d{0,10}(\.\d{1,6})?$', RTRIM( @cQty), 1) <> 1   -- (james03)
      IF @nCheckQTYFormat = 1
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'QTY', @cQTY) = 0
         BEGIN
            SET @nErrNo = 64286
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            GOTO Step_5_Fail_QTY
         END
      END
      ELSE
      BEGIN
         -- Check QTY field scanned barcode
         IF LEN( @cQTY) > 7  --KimMun
         BEGIN
            SET @nErrNo = 64265
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            GOTO Step_5_Fail_QTY
         END
      END

      -- Validate QTY convert to master unit become decimal
      DECLARE @fQTY FLOAT
      SET @fQTY = CAST( @cQTY AS FLOAT) -- Get UOM QTY (possible key-in as float)
      SET @fQTY = @fQTY * @nUOM_Div     -- Convert to master QTY

      SET @nQTY = CAST( @fQty AS INT) -- Convert float to int
      IF @nQTY <> @fQty               -- Test master QTY in float, should be int
      BEGIN
         SET @nErrNo = 64287
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64287 ', 'Convert decimal error'
         GOTO Step_5_Fail_QTY
      END

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToBaseQTY', @cStorer, @cSKU, @nQTY OUTPUT
      END

      -- Validate over receive
      IF @cDisAllowRDTOverReceipt = '1'
      BEGIN
         DECLARE @nTotalScanQty INT

         SELECT
            @nQtyExpected = ISNULL( SUM(QtyExpected), 0),
            @nTotalScanQty = ISNULL( SUM(BeforeReceivedQty), 0)
         FROM dbo.Receiptdetail WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND SKU = @cSKU
            AND Receiptkey = @cReceiptKey

         IF @nTotalScanQty + @nQTY > @nQtyExpected
         BEGIN
            SET @nErrNo = 64288
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64288 ', 'Over Receive'
            GOTO Step_5_Fail_QTY
         END
      END

      -- Retain QTY field
      SET @cOutField05 = @cQTY

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         -- (ChewKP04)
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQty,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            SET @cMax = ''
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = 4831
            SET @nStep = @nStep + 4
            
            GOTO Step_5_Quit
         END
      END

      --(cc01)
      IF @cAutoGotoLotScn = '1'
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = ''
         -- Go to lottable screen
         SET @nScn =  @nScn - 1
         SET @nStep = @nStep - 1
      END

      -- (james18)
      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PieceReceiving_Confirm -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_PieceReceiving_Confirm
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPoKey,  -- (ChewKP01)
         @cToLOC        = @cLOC,
         @cToID         = @cTOID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nQty,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = 'OK',
         @cSubreasonCode = '',
         @cReceiptLineNumber = @cReceiptLineNumber OUTPUT,
         @cSerialNo      = @cSerialNo,
         @nSerialQTY     = @nSerialQTY,
         @nBulkSNO       = @nBulkSNO,
         @nBulkSNOQTY    = @nBulkSNOQTY        --MT   
   

      IF @nErrNo <> 0
      BEGIN
         SET @cSKUValidated = '0'
         ROLLBACK TRAN rdt_PieceReceiving_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      ELSE
         SET @cSKUValidated = '0'

      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT
         @cPalletType = C_String1
         FROM RDT.RDTMOBREC (NOLOCK)
         WHERE  Mobile = @nMobile

         IF ISNULL(@cPalletType,'')!=''
         BEGIN
            UPDATE RECEIPTDETAIL SET PalletType = @cPalletType
            WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         END
      END

      -- (james04)
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cSKUValidated = '0' 
            ROLLBACK TRAN rdt_PieceReceiving_Confirm
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
         ELSE
            SET @cSKUValidated = '0'
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- (james23)
      SELECT @cBUSR1 = BUSR1
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   Sku = @cSKU

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '2', -- Receiving
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorer,
         @cLocation     = @cLOC,
         @cID           = @cTOID,
         @cSKU          = @cSku,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @nStep         = @nStep,
         @cRefNo3       = @cBUSR1,
         @cRefNo2       = @cReceiptLineNumber

      -- Get ToIDQTY
      SELECT @nToIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM   dbo.Receiptdetail WITH (NOLOCK)
      WHERE  receiptkey = @cReceiptkey
      AND    toloc = @cLOC
      AND    toid = @cTOID
      AND    Storerkey = @cStorer

      -- Get QTY statistic
      SELECT
         @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
         @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      --AND   POKey      = @cPOKey
      AND   SKU        = @cSKU
      AND   ToID       = @cToID
      AND   ToLoc      = @cLoc
      AND   Storerkey  = @cStorer

      -- Print SKU label
      IF @cSKULabel = '1'
         EXEC rdt.rdt_PieceReceiving_SKULabel @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cPrinter,
            @cReceiptKey,
            @cLOC,
            @cToID,
            @cSKU,
            @nQTY,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @dLottable05,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nBeforeReceivedQty OUTPUT
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nQtyExpected OUTPUT

         -- Get ToIDQTY
         DECLARE @nSKUQTY INT
         DECLARE @curIDSKU CURSOR
         SET @nToIDQTY = 0
         SET @nSKUQTY = 0
         SET @curIDSKU = CURSOR FOR
            SELECT SKU, ISNULL( SUM( BeforeReceivedQty), 0)
            FROM   dbo.Receiptdetail WITH (NOLOCK)
            WHERE  receiptkey = @cReceiptkey
            AND    toloc = @cLOC
            AND    toid = @cTOID
            AND    Storerkey = @cStorer
            GROUP BY SKU
            HAVING SUM( BeforeReceivedQty) > 0
         OPEN @curIDSKU
         FETCH NEXT FROM @curIDSKU INTO @cSKU, @nSKUQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nSKUQTY OUTPUT
            SET @nToIDQTY = @nToIDQTY + @nSKUQTY
            FETCH NEXT FROM @curIDSKU INTO @cSKU, @nSKUQTY
         END
      END

      -- (james22)
      IF @cDisAllowRDTOverReceipt = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     GROUP BY ReceiptKey
                     HAVING ISNULL( SUM( QtyExpected), 0) = ISNULL( SUM( BeforeReceivedQty), 0)
                     AND    ISNULL( SUM( BeforeReceivedQty), 0) > 0)
         BEGIN
            IF @cBackToASNScnWhenFullyRcv = '1'
            BEGIN
               -- Prepare prev screen var
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = '' -- ExtASN

               IF @cRefNo <> ''
                  EXEC rdt.rdtSetFocusField @nMobile, 3 -- Refno
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

               -- go to previous screen
               SET @nScn = @nScn - 4
               SET @nStep = @nStep - 4

               GOTO Quit
            END
         END
      END

      -- (james27)
      IF @cAfterReceiveGoBackToId = '1'
      BEGIN
         -- Prepare next screen variable
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = ''

         -- Go to next screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      
         GOTO Quit
      END
      
      -- Prep QTY fields
      SET @cOutField02 = '' -- SKU
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' + CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))

      SET @cBarcode = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
      SET @cVerifySKUInfo = ''   -- (james06)
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cEnableAllLottables = '1'
      BEGIN
         -- Init next screen var
         SET @cOutField01 = @cTOID
         SET @cOutField03 = '' -- SKUDesc1
         SET @cOutField04 = '' -- SKUDesc2
         SET @cMax = ''
         SET @nScn  = 4033
         SET @nStep = 12
         GOTO Quit
      END
      -- Prepare prev screen var
      SET @cOutField01 = @cTempLottable01
      SET @cOutField02 = @cTempLottable02
      SET @cOutField03 = @cTempLottable03
      SET @cOutField04 = @cTempLottable04

      -- Enable / disable field
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = ''
      SET @cFieldAttr05 = '' -- QTY

      -- Go to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- Lottable01

      -- (james13)
      IF @cSkipLottable = '1'
         GOTO Step_4
   END
   GOTO Step_5_Quit

   Step_5_Fail_SKU:
   BEGIN
      IF @nErrno = -1
      BEGIN
         IF @cExtScnSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
            BEGIN
               IF @cExtScnSP = 'rdt_1580ExtScn02'
               BEGIN
                  SET @nAction = 2
                  DELETE FROM @tExtScnData
                  INSERT INTO @tExtScnData (Variable, Value) VALUES                 
                  ('@cSKU',            @cSKU),
                  ('@nQTY',            CAST( @nQTY AS NVARCHAR( 10))),
                  ('@cBarcode',        @cBarcode)
               END

               EXECUTE [RDT].[rdt_ExtScnEntry]
                  @cExtScnSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @tExtScnData,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
                  @nAction,
                  @nScn OUTPUT,  @nStep OUTPUT,
                  @nErrNo   OUTPUT,
                  @cErrMsg  OUTPUT,
                  @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
                  @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
                  @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
                  @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
                  @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
                  @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
                  @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
                  @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
                  @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
                  @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @cSKU = ''
                  SET @cPrevBarcode = ''
                  SET @cOutField02 = '' -- SKU
                  SET @cBarcode = ''
                  
                  EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
                  GOTO Quit
               END

               IF @cExtScnSP = 'rdt_1580ExtScn02'
               BEGIN
                  SET @cBarcode = @cUDF01
                  SET @cPrevBarcode = @cUDF02
                  SET @cSKUValidated = @cUDF03
                  SET @nBeforeReceivedQty = @cUDF04
                  SET @nQtyExpected = @cUDF05
                  SET @nToIDQTY = @cUDF06
                  SET @cVerifySKUInfo = @cUDF07
               END
            END
         End
      END

      SET @cSKU = ''
      SET @cPrevBarcode = ''
      SET @cOutField02 = '' -- SKU
      SET @cBarcode = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

      
      GOTO Quit
   END

   Step_5_Fail_QTY:
   BEGIN
      SET @cSKUValidated = '0' -- INC1512999
      SET @cOutField05 = @cQTY -- QTY
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
      GOTO Quit
   END

   Step_5_Quit:
   BEGIN
      IF @cFlowThruScreen = '1'
      BEGIN
         IF @nStep = 9 -- Serial no
         BEGIN
            IF @cSerialNo <> ''
            BEGIN
               SET @cInField04 = @cSerialNo
               /*
                  Workaround to force use 1D SerialNo screen.
                  Cannot use 2D SerialNo screen, due to input is on V_Max, and V_Max cannot declare at parent module.
                  If declared, it overwrite SKULabel that output ZPL to V_Max also, at screen engine level
               */
               SET @nScn = 4830 -- 1D SerialNo screen

               GOTO Step_9
            END
         END
      END

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            IF OBJECT_SCHEMA_NAME( OBJECT_ID( 'rdt.' + @cExtendedInfoSP)) = 'rdt' 
            BEGIN 
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
                  ' @cReceiptKey, @cPOKey, @cRefNo, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, ' + 
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
               SET @cSQLParam =
                  ' @nMobile         INT,                    ' +  
                  ' @nFunc           INT,                    ' + 
                  ' @cLangCode       NVARCHAR( 3),           ' + 
                  ' @nStep           INT,                    ' + 
                  ' @nAfterStep      INT,                    ' + 
                  ' @nInputKey       INT,                    ' + 
                  ' @cFacility       NVARCHAR( 5),           ' + 
                  ' @cStorerKey      NVARCHAR( 15),          ' + 
                  ' @cReceiptKey     NVARCHAR( 10),          ' + 
                  ' @cPOKey          NVARCHAR( 10),          ' + 
                  ' @cRefNo          NVARCHAR( 20),          ' + 
                  ' @cToLOC          NVARCHAR( 10),          ' + 
                  ' @cToID           NVARCHAR( 18),          ' + 
                  ' @cLottable01     NVARCHAR( 18),          ' + 
                  ' @cLottable02     NVARCHAR( 18),          ' + 
                  ' @cLottable03     NVARCHAR( 18),          ' + 
                  ' @dLottable04     DATETIME,               ' + 
                  ' @cSKU            NVARCHAR( 20),          ' + 
                  ' @nQTY            INT,                    ' + 
                  ' @tVar            VariableTable READONLY, ' + 
                  ' @cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' + 
                  ' @nErrNo          INT           OUTPUT,   ' + 
                  ' @cErrMsg         NVARCHAR( 20) OUTPUT    ' 

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, 5, @nStep, @nInputKey, @cFacility, @cStorer, 
                  @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, 
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
               IF @nStep = 5
                  SET @cOutField15 = @cExtendedInfo
            END
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 6. Screen = 1755. Print pallet label?
 Option (field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 64289
         SET @cErrMsg = rdt.rdtgetmessage( 64289, @cLangCode, 'DSP') --Invalid option
         GOTO Step_6_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Check login printer
         IF @cPrinter = ''
         BEGIN
              SET @nErrNo = 64290
              SET @cErrMsg = rdt.rdtgetmessage( 64290, @cLangCode, 'DSP') --NoLoginPrinter
              GOTO Step_6_Fail
         END

         -- Get post receive label info
         DECLARE @cReporType NVARCHAR( 10)
         SELECT
            @cReporType = 'PostRecv',
            @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
            @cTargetDB = ISNULL(RTRIM(TargetDB), '')
         FROM RDT.RDTReport WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND ReportType = 'PostRecv'

         -- Get pallet label info
         IF @@ROWCOUNT = 0
            SELECT
               @cReporType = 'PalletLBL',
               @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
               @cTargetDB = ISNULL(RTRIM(TargetDB), '')
            FROM RDT.RDTReport WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND ReportType = 'PalletLBL'

         -- Check data window
         IF ISNULL( @cDataWindow, '') = ''
         BEGIN
            SET @nErrNo = 64291
            SET @cErrMsg = rdt.rdtgetmessage( 64291, @cLangCode, 'DSP') --DWNOTSetup
            GOTO Step_6_Fail
         END

         -- Check database
         IF ISNULL( @cTargetDB, '') = ''
         BEGIN
            SET @nErrNo = 64292
            SET @cErrMsg = rdt.rdtgetmessage( 64292, @cLangCode, 'DSP') --TgetDB Not Set
            GOTO Step_6_Fail
         END

         -- Print post receive label
         IF @cReporType = 'PostRecv'
         BEGIN
            -- Find receipt detai line
            SET @cReceiptLineNumber = ''
            SELECT TOP 1
               @cReceiptLineNumber = ReceiptLineNumber
            FROM ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND ToID = @cTOID

            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorer,
               'PostRecv',       -- ReportType
               'PRINT_PostRecv', -- PrintJobName
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cReceiptKey,
               @cReceiptLineNumber,
               @cReceiptLineNumber,
               @cToID -- (ChewKP05)
         END

         -- Print pallet label
         IF @cReporType = 'PalletLBL'
            EXEC RDT.rdt_BuiltPrintJob
               @nMobile,
               @cStorer,
               'PalletLBL',       -- ReportType
               'PRINT_PalletLBL', -- PrintJobName
               @cDataWindow,
               @cPrinter,
               @cTargetDB,
               @cLangCode,
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               @cReceiptKey,
               @cToID
      END

      -- Close pallet
      IF @cClosePallet ='1'
      BEGIN
         --some condition no need close pallet  --(cc01)  
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cClosePalletSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cClosePalletSP) +  
               ' @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cClosePalletOut OUTPUT'  
            SET @cSQLParam =  
               '@cReceiptKey   NVARCHAR( 10), ' +  
               '@cPOKey        NVARCHAR( 10), ' +  
               '@cLOC          NVARCHAR( 10), ' +  
               '@cToID         NVARCHAR( 18), ' +  
               '@cLottable01   NVARCHAR( 18), ' +  
               '@cLottable02   NVARCHAR( 18), ' +  
               '@cLottable03   NVARCHAR( 18), ' +  
               '@dLottable04   DATETIME,  ' +  
               '@cStorer       NVARCHAR( 15), ' +  
               '@cSKU          NVARCHAR( 20), ' +  
               '@cClosePalletOut NVARCHAR( 1) OUTPUT'  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cClosePalletOut OUTPUT  
                 
            IF @cClosePalletOut = '1'  
            BEGIN  
             -- Prepare next screen var  
               SET @cOutField01 = '' -- Option  
  
               -- Go message screen  
               SET @nScn = @nScn + 4  
               SET @nStep = @nStep + 4  
  
               GOTO Quit  
            END  
         END  
         ELSE IF @cClosePallet = '1'  
         BEGIN  
          -- Prepare next screen var  
            SET @cOutField01 = '' -- Option  
  
            -- Go message screen  
            SET @nScn = @nScn + 4  
            SET @nStep = @nStep + 4  
  
            GOTO Quit  
         END  
      END
      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT 
            @cPalletType = PalletType
         FROM dbo.PalletTypeMaster WITH (NOLOCK)
         WHERE StorerKey = @cStorer
         AND Facility = @cFacility
         AND PalletTypeInUse = 'Y'

         IF @@ROWCOUNT > 1
         BEGIN
            SET @cFieldAttr01='1'
            SET @cOutField01 = ''
            SET @nScn = 6382
            SET @nStep = 99
            GOTO Quit
         END
         ELSE
         BEGIN
            --Skip ID Screen
            SET @nAction = 3
            IF @cExtendedScreenSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
               BEGIN
                  EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                     @cExtendedScreenSP,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                     @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                     @nAction, 
                     @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                     @nErrNo   OUTPUT, 
                     @cErrMsg  OUTPUT
                  
                  IF @nErrNo <> 0
                     GOTO Quit
                  IF @nAfterStep <> 0
                  BEGIN
                     SET @nScn = @nAfterScn
                     SET @nStep = @nAfterStep
                     GOTO Quit
                  END
               END
            END
            -- Auto generate ID
            IF @cAutoGenID <> ''
            BEGIN
               EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                  ,@cAutoGenID
                  ,@cReceiptKey
                  ,@cPOKey
                  ,@cLOC
                  ,@cToID
                  ,@cOption
                  ,@cAutoID  OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Step_6_Fail

               SET @cToID = @cAutoID
            END
            ELSE
            BEGIN
               SET @cToID = ''
               SET @cAutoID = ''
            END

            -- Prepare prev screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = @cLOC
            SET @cOutField04 = @cToID

            -- Go to previous screen
            SET @nScn = @nScn - 3
            SET @nStep = @nStep - 3
            GOTO Quit
         END
      END
      --Skip ID Screen
      SET @nAction = 3
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
            IF @nAfterStep <> 0
            BEGIN
               SET @nScn = @nAfterScn
               SET @nStep = @nAfterStep
               GOTO Quit
            END
         END
      END
      -- Auto generate ID
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
            ,@cAutoGenID
            ,@cReceiptKey
            ,@cPOKey
            ,@cLOC
            ,@cToID
            ,@cOption
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_6_Fail

         SET @cToID = @cAutoID
      END
      ELSE
      BEGIN
         SET @cToID = ''
         SET @cAutoID = ''
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cToID

      -- Go to ID screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cSkipLottable = '1'
      BEGIN
         SET @nAction = 3
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
            BEGIN
               EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                  @cExtendedScreenSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                  @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                  @nAction, 
                  @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                  @nErrNo   OUTPUT, 
                  @cErrMsg  OUTPUT
               
               IF @nErrNo <> 0
                  GOTO Quit
               IF @nAfterStep <> 0
               BEGIN
                  SET @nScn = @nAfterScn
                  SET @nStep = @nAfterStep
                  GOTO Quit
               END
            END
         END
         -- Auto generate ID
         IF @cAutoGenID <> ''
         BEGIN
            EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
               ,@cAutoGenID
               ,@cReceiptKey
               ,@cPOKey
               ,@cLOC
               ,@cToID
               ,@cOption
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Quit

            SET @cToID = @cAutoID
         END
         ELSE
         BEGIN
            SET @cToID = ''
            SET @cAutoID = ''
         END

         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cToID

         -- Go to previous screen
         SET @nScn = @nScn - 3
         SET @nStep = @nStep - 3
      END
      ELSE
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cTempLottable01
         SET @cOutField02 = @cTempLottable02
         SET @cOutField03 = @cTempLottable03
         SET @cOutField04 = @cTempLottable04

         -- Disable lottable
         IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = ''
         IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = ''
         IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = ''
         IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = ''

         -- Go to lottable screen
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END
   GOTO Quit

   Step_6_Fail:
END
GOTO Quit


/********************************************************************************
Step 7. Screen = 1756. Verify SKU
 SKU         (Field01)
 SKUDesc1    (Field02)
 SKUDesc2    (Field03)
 Weight      (Field04, input)
 Cube        (Field05, input)
 Length      (Field06, input)
 Width       (Field07, input)
 Height      (Field08, input)
 InnerPack   (Field09, input)
 CaseCount   (Field10, input)
 PalletCount (Field11, input)
********************************************************************************/
Step_7:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cWeight      = @cInField04
      SET @cCube        = @cInField05
      SET @cLength      = @cInField06
      SET @cWidth       = @cInField07
      SET @cHeight      = @cInField08
      SET @cInnerPack   = @cInField09
      SET @cCaseCount   = @cInField10
      SET @cPalletCount = @cInField11
      SET @cVerifySKUInfo = @cInField12

      -- Retain key-in value
      SET @cOutField04 = @cInField04
      SET @cOutField05 = @cInField05
      SET @cOutField06 = @cInField06
      SET @cOutField07 = @cInField07
      SET @cOutField08 = @cInField08
      SET @cOutField09 = @cInField09
      SET @cOutField10 = @cInField10
      SET @cOutField11 = @cInField11
      SET @cOutField12 = @cInField12

      -- Update SKU setting
      EXEC rdt.rdt_VerifySKU @nMobile, @nFunc, @cLangCode, @cStorer, @cSKU, 'UPDATE',
         @cWeight        OUTPUT,
         @cCube          OUTPUT,
         @cLength        OUTPUT,
         @cWidth         OUTPUT,
         @cHeight        OUTPUT,
         @cInnerPack     OUTPUT,
         @cCaseCount     OUTPUT,
         @cPalletCount   OUTPUT,
         @nErrNo         OUTPUT,
         @cErrMsg        OUTPUT,
         @cVerifySKUInfo OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
   END

    -- Enable field
   SELECT @cFieldAttr04 = ''
   SELECT @cFieldAttr05 = ''
   SELECT @cFieldAttr06 = ''
   SELECT @cFieldAttr07 = ''
   SELECT @cFieldAttr08 = ''
   SELECT @cFieldAttr09 = ''
   SELECT @cFieldAttr10 = ''
   SELECT @cFieldAttr11 = ''
   SELECT @cFieldAttr12 = ''

   -- Disable and default QTY field
   IF rdt.RDTGetConfig( 0, 'ReceiveByPieceDisableQTYField', @cStorer) = '1'
      SET @cFieldAttr05 = 'O' -- QTY

   -- Prepare SKU fields
   SET @cOutField01 = @cToID
   SET @cOutField02 = @cSKU
   SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
   SET @cOutField05 = CASE WHEN ISNULL( @cDefaultPieceRecvQTY, '') = '' THEN @cQty ELSE @cDefaultPieceRecvQTY END
   SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
   SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))
   SET @cOutField11 = @cSKU -- last SKU
   SET @cOutField12 = @cUOM -- last UOM
   SET @cOutField15 = '' --@cExtendedInfo

   SET @cBarcode = @cSKU
   
   IF ISNULL( @cOutField02, '') = ''
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
   ELSE
      EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY

   -- Go to SKU QTY screen
   SET @nScn = 1754 -- @nScn - 2
   SET @nStep = @nStep - 2

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         IF OBJECT_SCHEMA_NAME( OBJECT_ID( 'rdt.' + @cExtendedInfoSP)) = 'rdt' 
         BEGIN 
            SET @cExtendedInfo = ''
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
             SET @cSQLParam =
               ' @nMobile         INT,                    ' +  
               ' @nFunc           INT,                    ' + 
               ' @cLangCode       NVARCHAR( 3),           ' + 
               ' @nStep           INT,                    ' + 
               ' @nAfterStep      INT,                    ' + 
               ' @nInputKey       INT,                    ' + 
               ' @cFacility       NVARCHAR( 5),           ' + 
               ' @cStorerKey      NVARCHAR( 15),          ' + 
               ' @cReceiptKey     NVARCHAR( 10),          ' + 
               ' @cPOKey          NVARCHAR( 10),          ' + 
               ' @cRefNo          NVARCHAR( 20),          ' + 
               ' @cToLOC          NVARCHAR( 10),          ' + 
               ' @cToID           NVARCHAR( 18),          ' + 
               ' @cLottable01     NVARCHAR( 18),          ' + 
               ' @cLottable02     NVARCHAR( 18),          ' + 
               ' @cLottable03     NVARCHAR( 18),          ' + 
               ' @dLottable04     DATETIME,               ' + 
               ' @cSKU            NVARCHAR( 20),          ' + 
               ' @nQTY            INT,                    ' + 
               ' @tVar            VariableTable READONLY, ' + 
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' + 
               ' @nErrNo          INT           OUTPUT,   ' + 
               ' @cErrMsg         NVARCHAR( 20) OUTPUT    ' 

             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 7, @nStep, @nInputKey, @cFacility, @cStorer, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nStep = 5 -- SKU, QTY
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 8. Screen = 1757. Multi SKU
 SKU         (Field01)
 SKUDesc1    (Field02)
 SKUDesc2    (Field03)
 SKU         (Field04)
 SKUDesc1    (Field05)
 SKUDesc2    (Field06)
 SKU         (Field07)
 SKUDesc1    (Field08)
 SKUDesc2    (Field09)
 Option      (Field10, input)
********************************************************************************/
Step_8:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         'CHECK',
         @cMultiSKUBarcode,
         @cStorer,
         @cSKU     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

      IF @nErrNo <> 0
      BEGIN
         IF @nErrNo = -1
            SET @nErrNo = 0
         GOTO Quit
      END

      -- Get SKU info
      SELECT @cSKUDesc = 
         CASE WHEN @cDispStyleColorSize = '0'
              THEN ISNULL( DescR, '')
              ELSE CAST( Style AS NCHAR(20)) +
                   CAST( Color AS NCHAR(10)) +
                   CAST( Size  AS NCHAR(10))
         END
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorer 
         AND SKU = @cSKU
   END

   -- Prepare SKU fields
   SET @cOutField01 = @cToID
   SET @cOutField02 = @cSKU
   SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
   SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
   SET @cOutField05 = @cDefaultPieceRecvQTY
   SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
   SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))
   SET @cOutField11 = @cSKU -- last SKU
   SET @cOutField12 = @cUOM -- last UOM
   SET @cOutField15 = '' -- @cExtendedInfo

   SET @cBarcode = @cSKU
   
   EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

   -- Go to SKU QTY screen
   SET @nScn = @nFromScn
   SET @nStep = @nStep - 3

   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         IF OBJECT_SCHEMA_NAME( OBJECT_ID( 'rdt.' + @cExtendedInfoSP)) = 'rdt' 
         BEGIN 
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,                    ' +  
               ' @nFunc           INT,                    ' + 
               ' @cLangCode       NVARCHAR( 3),           ' + 
               ' @nStep           INT,                    ' + 
               ' @nAfterStep      INT,                    ' + 
               ' @nInputKey       INT,                    ' + 
               ' @cFacility       NVARCHAR( 5),           ' + 
               ' @cStorerKey      NVARCHAR( 15),          ' + 
               ' @cReceiptKey     NVARCHAR( 10),          ' + 
               ' @cPOKey          NVARCHAR( 10),          ' + 
               ' @cRefNo          NVARCHAR( 20),          ' + 
               ' @cToLOC          NVARCHAR( 10),          ' + 
               ' @cToID           NVARCHAR( 18),          ' + 
               ' @cLottable01     NVARCHAR( 18),          ' + 
               ' @cLottable02     NVARCHAR( 18),          ' + 
               ' @cLottable03     NVARCHAR( 18),          ' + 
               ' @dLottable04     DATETIME,               ' + 
               ' @cSKU            NVARCHAR( 20),          ' + 
               ' @nQTY            INT,                    ' + 
               ' @tVar            VariableTable READONLY, ' + 
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' + 
               ' @nErrNo          INT           OUTPUT,   ' + 
               ' @cErrMsg         NVARCHAR( 20) OUTPUT    ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 8, @nStep, @nInputKey, @cFacility, @cStorer, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nStep = 5 -- SKU, QTY
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
END
GOTO Quit


/********************************************************************************
Step 9. Screen = 4831. Serial No
 SKU            (Field01)
 SKUDesc1       (Field02)
 SKUDesc2       (Field03)
 SerialNo       (Field04, input)
 Scan           (Field05)
********************************************************************************/
Step_9:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Extended validate (yeekung05)
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrno = -1
         BEGIN
            SET @nScn = 6413
            SET @nStep = 98
            SET @cOutField01 = @cMax
            SET @cOutField02 = ''
            GOTO Step_9_fail
         END

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_9_Quit
      END

      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cSKU, @cSKUDesc, @nQTY, 'UPDATE', 'ASN', @cReceiptKey,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '2'

      IF @nErrNo = -1
      BEGIN
         -- Get QTY statistic
         SELECT
            @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
            @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE Receiptkey = @cReceiptKey
         --AND   POKey      = @cPOKey
         AND   SKU        = @cSKU
         AND   ToID       = @cToID
         AND   ToLoc      = @cLoc
         AND   Storerkey  = @cStorer

         SET @cSKUValidated = '0'

         -- Prepare next screen variable
         SET @cPrevBarcode = ''
         SET @cOutField01 = @cToID
         SET @cOutField02 = '' -- sku
         SET @cOutField03 = '' -- sku desc1
         SET @cOutField04 = '' -- sku desc2
         SET @cOutField05 = @cDefaultPieceRecvQTY
         SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
         SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
         SET @cOutField11 = @cSKU -- last SKU
         SET @cOutField12 = @cUOM -- last UOM
         SET @cOutField15 = '' -- @cExtendedInfo

         SET @cBarcode = ''

         SET @cInField05 = @cDefaultPieceRecvQTY
         EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

         -- Go to SKU QTY screen
         SET @nScn = @nFromScn
         SET @nStep = @nStep - 4

         GOTO Step_9_Quit
      END

      IF @nErrNo <> 0 -- (james31)
         GOTO Quit

      DECLARE @nRDQTY INT
      IF @nBulkSNO > 0
         SET @nRDQTY = @nBulkSNOQTY
      ELSE IF @cSerialNo <> ''
         SET @nRDQTY = @nSerialQTY
      ELSE
         SET @nRDQTY = @nQTY

      -- Receive
      EXEC rdt.rdt_PieceReceiving_Confirm
         @nFunc      = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPoKey,  -- (ChewKP01)
         @cToLOC        = @cLOC,
         @cToID         = @cTOID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nRDQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = 'OK',
         @cSubreasonCode = '',
         @cReceiptLineNumber = @cReceiptLineNumber OUTPUT,
         @cSerialNo      = @cSerialNo,
         @nSerialQTY     = @nSerialQTY,
         @nBulkSNO       = @nBulkSNO,
         @nBulkSNOQTY    = @nBulkSNOQTY

      IF @nErrno <> 0
         GOTO Quit
      ELSE
         SET @cSKUValidated = '0'
      
      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT
         @cPalletType = C_String1
         FROM RDT.RDTMOBREC (NOLOCK)
         WHERE  Mobile = @nMobile

         IF ISNULL(@cPalletType,'')!=''
         BEGIN
            UPDATE RECEIPTDETAIL SET PalletType = @cPalletType
            WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         END
      END

      -- (james23)
      SELECT @cBUSR1 = BUSR1
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   Sku = @cSKU

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '2', -- Receiving
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorer,
         @cLocation     = @cLOC,
         @cID           = @cTOID,
         @cSKU          = @cSku,
         @cUOM          = @cUOM,
         @nQTY          = @nRDQTY,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @nStep         = @nStep,
         @cSerialNo     = @cSerialNo,
         @cRefNo3       = @cBUSR1,
         @cRefNo2       = @cReceiptLineNumber

      SET @cMax = ''

      IF @nMoreSNO = 1
         GOTO Quit

      -- Get ToIDQTY
      SELECT @nToIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM   dbo.Receiptdetail WITH (NOLOCK)
      WHERE  receiptkey = @cReceiptkey
      AND    toloc = @cLOC
      AND    toid = @cTOID
      AND    Storerkey = @cStorer

      -- Get QTY statistic
      SELECT
         @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
         @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      --AND   POKey      = @cPOKey
      AND   SKU        = @cSKU
      AND   ToID       = @cToID
      AND   ToLoc      = @cLoc
      AND   Storerkey  = @cStorer

      -- Print SKU label
      IF @cSKULabel = '1'
         EXEC rdt.rdt_PieceReceiving_SKULabel @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cPrinter,
            @cReceiptKey,
            @cLOC,
            @cToID,
            @cSKU,
            @nQTY,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @dLottable05,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))
      SET @cOutField11 = @cSKU -- last SKU
      SET @cOutField12 = @cUOM -- last UOM
      SET @cOutField15 = '' -- @cExtendedInfo

      SET @cBarcode = ''

      SET @cInField05 = @cDefaultPieceRecvQTY
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 4
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Step_9_Quit
      END
      
      SET @cSKUValidated = '0'

      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = '' -- @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))
      SET @cOutField11 = @cSKU -- last SKU
      SET @cOutField12 = @cUOM -- last UOM
      SET @cOutField15 = '' -- @cExtendedInfo

      SET @cBarcode = ''

      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU

      -- Go to SKU QTY screen
      SET @nScn = @nFromScn
      SET @nStep = @nStep - 4
   END

Step_9_Quit:
   -- Extended info
   IF @cExtendedInfoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
      BEGIN
         IF OBJECT_SCHEMA_NAME( OBJECT_ID( 'rdt.' + @cExtendedInfoSP)) = 'rdt' 
         BEGIN 
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' + 
               ' @cReceiptKey, @cPOKey, @cRefNo, @cToLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile         INT,                    ' +  
               ' @nFunc           INT,                    ' + 
               ' @cLangCode       NVARCHAR( 3),           ' + 
               ' @nStep           INT,                    ' + 
               ' @nAfterStep      INT,                    ' + 
               ' @nInputKey       INT,                    ' + 
               ' @cFacility       NVARCHAR( 5),           ' + 
               ' @cStorerKey      NVARCHAR( 15),          ' + 
               ' @cReceiptKey     NVARCHAR( 10),          ' + 
               ' @cPOKey          NVARCHAR( 10),          ' + 
               ' @cRefNo          NVARCHAR( 20),          ' + 
               ' @cToLOC          NVARCHAR( 10),          ' + 
               ' @cToID           NVARCHAR( 18),          ' + 
               ' @cLottable01     NVARCHAR( 18),          ' + 
               ' @cLottable02     NVARCHAR( 18),          ' + 
               ' @cLottable03     NVARCHAR( 18),          ' + 
               ' @dLottable04     DATETIME,               ' + 
               ' @cSKU            NVARCHAR( 20),          ' + 
               ' @nQTY            INT,                    ' + 
               ' @tVar            VariableTable READONLY, ' + 
               ' @cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' + 
               ' @nErrNo          INT           OUTPUT,   ' + 
               ' @cErrMsg         NVARCHAR( 20) OUTPUT    ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 9, @nStep, @nInputKey, @cFacility, @cStorer, 
               @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @tVar, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            
            IF @nStep = 5 -- SKU, QTY
               SET @cOutField15 = @cExtendedInfo
         END
      END
   END
   GOTO Quit
Step_9_fail:

END
GOTO Quit


/********************************************************************************
Step 10. Screen = 1759. Close pallet?
 Option (field01, input)
********************************************************************************/
Step_10:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField01

      -- Check invalid option
      IF @cOption NOT IN ('1', '2')
      BEGIN
         SET @nErrNo = 64296
         SET @cErrMsg = rdt.rdtgetmessage( 64296, @cLangCode, 'DSP') --Invalid option
         GOTO Quit
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Extended update
         IF @cExtendedUpdateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
               ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cReceiptKey  NVARCHAR( 10), ' +
               '@cPOKey       NVARCHAR( 10), ' +
               '@cExtASN      NVARCHAR( 20), ' +
               '@cToLOC       NVARCHAR( 10), ' +
               '@cToID        NVARCHAR( 18), ' +
               '@cLottable01  NVARCHAR( 18), ' +
               '@cLottable02  NVARCHAR( 18), ' +
               '@cLottable03  NVARCHAR( 18), ' +
               '@dLottable04  DATETIME,      ' +
               '@cSKU         NVARCHAR( 20), ' +
               '@nQTY         INT,           ' +
               '@nAfterStep   INT,           ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
             @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nStep,
                 @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END
      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT 
            @cPalletType = PalletType
         FROM dbo.PalletTypeMaster WITH (NOLOCK)
         WHERE StorerKey = @cStorer
         AND Facility = @cFacility
         AND PalletTypeInUse = 'Y'

         IF @@ROWCOUNT > 1
         BEGIN
            SET @cFieldAttr01='1'
            SET @cOutField01 = ''
            SET @nScn = 6382
            SET @nStep = 99
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nAction = 3
            IF @cExtendedScreenSP <> ''
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
               BEGIN
                  EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                     @cExtendedScreenSP,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                     @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                     @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                     @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                     @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                     @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                     @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                     @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                     @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                     @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                     @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                     @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                     @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                     @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                     @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                     @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                     @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                     @nAction, 
                     @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                     @nErrNo   OUTPUT, 
                     @cErrMsg  OUTPUT
                  
                  IF @nErrNo <> 0
                     GOTO Quit
                  IF @nAfterStep <> 0
                  BEGIN
                     SET @nScn = @nAfterScn
                     SET @nStep = @nAfterStep
                     GOTO Quit
                  END
               END
            END
            -- Auto generate ID
            IF @cAutoGenID <> ''
            BEGIN
               EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                  ,@cAutoGenID
                  ,@cReceiptKey
                  ,@cPOKey
                  ,@cLOC
                  ,@cToID
                  ,@cOption
                  ,@cAutoID  OUTPUT
                  ,@nErrNo   OUTPUT
                  ,@cErrMsg  OUTPUT
               IF @nErrNo <> 0
                  GOTO Quit

               SET @cToID = @cAutoID
            END
            ELSE
            BEGIN
               SET @cToID = ''
               SET @cAutoID = ''
            END

            -- Prepare prev screen var
            SET @cOutField01 = @cReceiptKey
            SET @cOutField02 = @cPOKey
            SET @cOutField03 = @cLOC
            SET @cOutField04 = @cToID

            -- Go to previous screen
            SET @nScn = @nScn - 7
            SET @nStep = @nStep - 7
         END
      END
      --Skip ID Screen
      SET @nAction = 3
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Quit
            IF @nAfterStep <> 0
            BEGIN
               SET @nScn = @nAfterScn
               SET @nStep = @nAfterStep
               GOTO Quit
            END
         END
      END
      -- Auto generate ID
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
            ,@cAutoGenID
            ,@cReceiptKey
            ,@cPOKey
            ,@cLOC
            ,@cToID
            ,@cOption
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         SET @cToID = @cAutoID
      END
      ELSE
      BEGIN
         SET @cToID = ''
         SET @cAutoID = ''
      END

      -- Prepare next screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cToID

      -- Go to ID screen
      SET @nScn = @nScn - 7
      SET @nStep = @nStep - 7
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      IF @cSkipLottable = '1'
      BEGIN
         IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
         BEGIN
            SELECT 
               @cPalletType = PalletType
            FROM dbo.PalletTypeMaster WITH (NOLOCK)
            WHERE StorerKey = @cStorer
            AND Facility = @cFacility
            AND PalletTypeInUse = 'Y'

            IF @@ROWCOUNT > 1
            BEGIN
               SET @cFieldAttr01='1'
               SET @cOutField01 = ''
               SET @nScn = 6382
               SET @nStep = 99
               GOTO Quit
            END
            ELSE
            BEGIN
               SET @nAction = 3
               IF @cExtendedScreenSP <> ''
               BEGIN
                  IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
                  BEGIN
                     EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                        @cExtendedScreenSP,
                        @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                        @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                        @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                        @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                        @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                        @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                        @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                        @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                        @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                        @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                        @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                        @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                        @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                        @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                        @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                        @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                        @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                        @nAction, 
                        @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                        @nErrNo   OUTPUT, 
                        @cErrMsg  OUTPUT
                     
                     IF @nErrNo <> 0
                        GOTO Quit
                     IF @nAfterStep <> 0
                     BEGIN
                        SET @nScn = @nAfterScn
                        SET @nStep = @nAfterStep
                        GOTO Quit
                     END
                  END
               END
               -- Auto generate ID
               IF @cAutoGenID <> ''
               BEGIN
                  EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
                     ,@cAutoGenID
                     ,@cReceiptKey
                     ,@cPOKey
                     ,@cLOC
                     ,@cToID
                     ,@cOption
                     ,@cAutoID  OUTPUT
                     ,@nErrNo   OUTPUT
                     ,@cErrMsg  OUTPUT
                  IF @nErrNo <> 0
                     GOTO Step_4_Fail

                  SET @cToID = @cAutoID
               END
               ELSE
               BEGIN
                  SET @cToID = ''
                  SET @cAutoID = ''
               END

               -- Prepare prev screen var
               SET @cOutField01 = @cReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = @cLOC
               SET @cOutField04 = @cToID

               -- Go to previous screen
               SET @nScn = @nScn - 7
               SET @nStep = @nStep - 7
            END
         END

         SET @nAction = 3
         IF @cExtendedScreenSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
            BEGIN
               EXECUTE [RDT].[rdt_1580ExtScnEntry] 
                  @cExtendedScreenSP,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
                  @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
                  @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
                  @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
                  @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
                  @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
                  @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
                  @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
                  @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
                  @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
                  @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
                  @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
                  @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
                  @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
                  @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
                  @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
                  @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
                  @nAction, 
                  @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
                  @nErrNo   OUTPUT, 
                  @cErrMsg  OUTPUT
               
               IF @nErrNo <> 0
                  GOTO Quit
               IF @nAfterStep <> 0
               BEGIN
                  SET @nScn = @nAfterScn
                  SET @nStep = @nAfterStep
                  GOTO Quit
               END
            END
         END
         -- Auto generate ID
         IF @cAutoGenID <> ''
         BEGIN
            EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
               ,@cAutoGenID
               ,@cReceiptKey
               ,@cPOKey
               ,@cLOC
               ,@cToID
               ,@cOption
               ,@cAutoID  OUTPUT
               ,@nErrNo   OUTPUT
               ,@cErrMsg  OUTPUT
            IF @nErrNo <> 0
               GOTO Step_4_Fail

            SET @cToID = @cAutoID
         END
         ELSE
         BEGIN
            SET @cToID = ''
            SET @cAutoID = ''
         END

         -- Prepare prev screen var
         SET @cOutField01 = @cReceiptKey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = @cToID

         -- Go to previous screen
         SET @nScn = @nScn - 7
         SET @nStep = @nStep - 7
      END
      ELSE
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cTempLottable01
         SET @cOutField02 = @cTempLottable02
         SET @cOutField03 = @cTempLottable03
         SET @cOutField04 = @cTempLottable04

         -- Disable lottable
         IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = ''
         IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = ''
         IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = ''
         IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = ''

         -- Go to lottable screen
         SET @nScn = @nScn - 6
         SET @nStep = @nStep - 6
      END
   END
END
GOTO Quit

/********************************************************************************
Step 11. Scn = 3490. Dynamic lottables
   Label01    (field01)
   Lottable01 (field02, input)
   Label02    (field03)
   Lottable02 (field04, input)
   Label03    (field05)
   Lottable03 (field06, input)
   Label04    (field07)
   Lottable04 (field08, input)
   Label05    (field09)
   Lottable05 (field10, input)
********************************************************************************/
Step_11:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      DECLARE @cOutField15Backup NVARCHAR( 60) = @cOutField15
      IF @cOutField15 = ''
		   SET @cOutField15='1,1'
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'CHECK', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Disable and default QTY field
      IF rdt.RDTGetConfig( 0, 'ReceiveByPieceDisableQTYField', @cStorer) = '1'
      BEGIN
         SET @cFieldAttr05 = 'O' -- QTY
         SET @cDefaultPieceRecvQTY = '1'
      END
      ELSE
      BEGIN
         -- Get default QTY
         SET @cDefaultPieceRecvQTY = rdt.RDTGetConfig( 0, 'DefaultPieceRecvQTY', @cStorer)
         IF @cDefaultPieceRecvQTY = '0'
            SET @cDefaultPieceRecvQTY = ''
      END

      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField12 = @cUOM
      SET @cOutField15 = @cExtendedInfo
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
      SET @cInField05 = @cDefaultPieceRecvQTY

      SET @cVerifySKUInfo = ''   -- (james06)
      SET @nScn = 6415
      SET @nStep = 13
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nMorePage = 1 -- Yes
         GOTO Quit

      -- Init next screen var
      SET @cOutField01 = @cTOID
      SET @cSKU = ''
      SET @cBarcode = ''
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cMax = ''
      SET @nScn = 4033
      SET @nStep = 12
   END
   GOTO Quit

   Step_11_Fail:
   -- After captured lottable, screen exit and the hidden field (O_Field15) is clear.
   -- If any error occur, need to simulate as if still staying in lottable screen, by restoring this hidden field
   SET @cOutField15 = @cOutField15Backup
END
GOTO Quit

/********************************************************************************
Step 12. Scn = 4033. SKU screen
 TO ID     (field01)
 SKU       (field02, input)
 SKU       (field11)
 Desc1     (field03)
 Desc2     (field04)
********************************************************************************/
Step_12:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cBarcode = @cMax
      SET @cBarcode = SUBSTRING( @cBarcode, 1, 2000)
      SET @cSKU = @cBarcode -- SKU
      --SET @cSKU = @cInField02 -- SKU

      -- Validate SKU
      IF ISNULL( @cSKU,'') = ''
      BEGIN
         SET @nErrNo = 64273
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64273 ', 'SKU Required'
         EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
         GOTO Quit
      END

      IF @cSKUValidated = '0'
      BEGIN
         -- Decode
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            SET @nDecodeQTY = 0
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cBarcode,
               @cUPC    = @cSKU    OUTPUT,
               @nQTY    = @nDecodeQTY    OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UPC'

             -- (james15)
              IF @nDecodeQTY > 0
                 SET @cQTY = @nDecodeQTY
         END
         ELSE
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSP AND type = 'P')
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cReceiptKey, @cPOKey, @cLOC, @cID, @cBarcode, ' +
                  ' @cSKU        OUTPUT, @nQTY        OUTPUT, ' +
                  ' @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @cSerialNoCapture OUTPUT, ' +
                  ' @nErrNo      OUTPUT, @cErrMsg     OUTPUT'
               SET @cSQLParam =
                  ' @nMobile           INT,           ' +
                  ' @nFunc             INT,           ' +
                  ' @cLangCode         NVARCHAR( 3),  ' +
                  ' @nStep             INT,           ' +
                  ' @nInputKey         INT,           ' +
                  ' @cStorerKey        NVARCHAR( 15), ' +
                  ' @cReceiptKey       NVARCHAR( 10), ' +
                  ' @cPOKey            NVARCHAR( 10), ' +
                  ' @cLOC              NVARCHAR( 10), ' +
                  ' @cID               NVARCHAR( 18), ' +
                  ' @cBarcode          NVARCHAR( MAX), ' +
                  ' @cSKU              NVARCHAR( 20)  OUTPUT, ' +
                  ' @nQTY              INT            OUTPUT, ' +
                  ' @cLottable01       NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable02       NVARCHAR( 18)  OUTPUT, ' +
                  ' @cLottable03       NVARCHAR( 18)  OUTPUT, ' +
                  ' @dLottable04       DATETIME       OUTPUT, ' +
                  ' @cSerialNoCapture  NVARCHAR(1)    OUTPUT, ' +
                  ' @nErrNo            INT            OUTPUT, ' +
                  ' @cErrMsg           NVARCHAR( 20)  OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorer, @cReceiptKey, @cPOKey, @cLOC, @cTOID, @cBarcode,
                  @cSKU        OUTPUT, @nQTY        OUTPUT,
                  @cLottable01 OUTPUT, @cLottable02 OUTPUT, @cLottable03 OUTPUT, @dLottable04 OUTPUT, @cSerialNoCapture OUTPUT,
                  @nErrNo      OUTPUT, @cErrMsg     OUTPUT

               IF @nErrNo <> 0
                  GOTO Step_5_Fail_SKU

              IF @nQTY > 0
                 SET @cQTY = CAST( @nQTY AS NVARCHAR( 5))

               SET @cTempLottable01 = CASE WHEN ISNULL( @cLottable01, '') <> '' THEN @cLottable01 ELSE @cTempLottable01 END
               SET @cTempLottable02 = CASE WHEN ISNULL( @cLottable02, '') <> '' THEN @cLottable02 ELSE @cTempLottable02 END
               SET @cTempLottable03 = CASE WHEN ISNULL( @cLottable03, '') <> '' THEN @cLottable03 ELSE @cTempLottable03 END
               SET @cTempLottable04 = CASE WHEN ISNULL( @dLottable04, '') <> '' THEN rdt.RDTFORMATDATE(@dLottable04)
                                      ELSE @cTempLottable04 END   -- (james30)
            END
            ELSE
            BEGIN
               -- Label decoding
               IF @cDecodeLabelNo <> ''
               BEGIN
                  SET @c_oFieled01 = @cSKU
                  SET @c_oFieled03 = @cTempLottable06
                  SET @c_oFieled05 = @cQTY
                  SET @c_oFieled07 = @cTempLottable01
                  SET @c_oFieled08 = @cTempLottable02
                  SET @c_oFieled09 = @cTempLottable03
                  SET @c_oFieled10 = @cTempLottable04

                  EXEC dbo.ispLabelNo_Decoding_Wrapper
                      @c_SPName     = @cDecodeLabelNo
                     ,@c_LabelNo    = @cBarcode --(yeekung01)
                     ,@c_Storerkey  = @cStorer
                     ,@c_ReceiptKey = @cReceiptkey
                     ,@c_POKey      = ''
                     ,@c_LangCode   = @cLangCode
                     ,@c_oFieled01  = @c_oFieled01 OUTPUT   -- SKU
                     ,@c_oFieled02  = @c_oFieled02 OUTPUT   -- STYLE
                     ,@c_oFieled03  = @c_oFieled03 OUTPUT   -- COLOR
                     ,@c_oFieled04  = @c_oFieled04 OUTPUT   -- SIZE
                     ,@c_oFieled05  = @c_oFieled05 OUTPUT   -- QTY
                     ,@c_oFieled06  = @c_oFieled06 OUTPUT   -- CO#
                     ,@c_oFieled07  = @c_oFieled07 OUTPUT   -- Lottable01
                     ,@c_oFieled08  = @c_oFieled08 OUTPUT   -- Lottable02
                     ,@c_oFieled09  = @c_oFieled09 OUTPUT   -- Lottable03
                     ,@c_oFieled10  = @c_oFieled10 OUTPUT   -- Lottable04
                     ,@b_Success    = @b_Success   OUTPUT
                     ,@n_ErrNo      = @nErrNo     OUTPUT
                     ,@c_ErrMsg     = @cErrMsg     OUTPUT

                  IF ISNULL(@cErrMsg, '') <> ''
                  BEGIN
                     SET @cErrMsg1 = @cErrMsg
                     SET @nErrNo = 0
                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                     IF @nErrNo = 1
                        SET @cErrMsg1 = ''

                     GOTO Step_12_Fail_SKU
                  END

                  SET @cSKU = @c_oFieled01
                  SET @cSerialNo = @c_oFieled02 -- (james19)
                  SET @cTempLottable06 = @c_oFieled03
                  SET @cQTY = @c_oFieled05
                  SET @cTempLottable01 = @c_oFieled07
                  SET @cTempLottable02 = @c_oFieled08
                  SET @cTempLottable03 = @c_oFieled09
                  SET @cTempLottable04 = @c_oFieled10
               END
            END
         END
      END

      -- Get SKU/UPC
      SET @nSKUCnt = 0

      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorer
         ,@cSKU        = @cSKU
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Validate SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 64274
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64274 ', 'Invalid SKU'
         GOTO Step_12_Fail_SKU
      END

      IF @nSKUCnt = 1
      BEGIN
         --SET @cSKU = @cSKUCode
         EXEC [RDT].[rdt_GETSKU]
             @cStorerKey  = @cStorer
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
            ,@nUPCQty     = @nUPCQty       OUTPUT

         IF @nUPCQty > 0
            SET @cQTY = @nUPCQty
      END

      -- Validate barcode return multiple SKU
      IF @nSKUCnt > 1
      BEGIN
         IF @cMultiSKUBarcode IN ('1', '2')
         BEGIN
            SET @cDocType = ''
            SET @cDocNo = ''

            IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInASN', @cStorer) = '1' OR -- 1=On,  means check SKU in ASN
               rdt.RDTGetConfig( @nFunc, 'SkipCheckingSKUNotInASN', @cStorer) = '0'        -- 0=Off, means check SKU in ASN
            BEGIN
               SET @cDocType = 'ASN'
               SET @cDocNo = @cReceiptKey
            END

            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,
               'POPULATE',
               @cMultiSKUBarcode,
               @cStorer,
               @cSKU     OUTPUT,
               @nErrNo   OUTPUT,
               @cErrMsg  OUTPUT,
               @cDocType,
               @cDocNo

            IF @nErrNo = 0 -- Populate multi SKU screen
            BEGIN
               -- Go to Multi SKU screen
               SET @nFromScn = @nScn
               SET @nScn = 3570
               SET @nStep = 8
               GOTO Quit
            END
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen
               SET @nErrNo = 0
         END
         ELSE
         BEGIN
            SET @nErrNo = 64276
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64276 ', 'Multi SKU barcode'
            GOTO Step_5_Fail_SKU
         END
      END

      -- Validate SKU in PO
      IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInPO', @cStorer) = '1' AND @cPOKey <> '' AND @cPOKey <> 'NOPO'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail  WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU
               AND POKey = @cPOKey
               AND Receiptkey = @cReceiptKey)
         BEGIN
            SET @nErrNo = 64277
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64277 ', 'SKU Not in PO'
            GOTO Step_12_Fail_SKU
         END
      END

      -- Validate SKU in ASN
      IF rdt.RDTGetConfig( @nFunc, 'ReceiveByPieceCheckSKUInASN', @cStorer) = '1'
      BEGIN
         IF NOT EXISTS( SELECT 1
            FROM dbo.Receiptdetail WITH (NOLOCK)
            WHERE StorerKey = @cStorer
               AND SKU = @cSKU
               AND Receiptkey = @cReceiptKey)
         BEGIN
            SET @nErrNo = 64278
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64278 ', 'SKU Not in ASN'
            GOTO Step_12_Fail_SKU
         END
      END

      -- Get SKU info
      SELECT
         @cSKUDesc =
            CASE WHEN @cDispStyleColorSize = '0'
                 THEN ISNULL( DescR, '')
                 ELSE CAST( Style AS NCHAR(20)) +
                      CAST( Color AS NCHAR(10)) +
                      CAST( Size  AS NCHAR(10))
            END,
         @cPackkey = PackKey,
         @cLottableLabel01 = IsNULL(Lottable01Label, ''),
         @cLottableLabel02 = IsNULL(Lottable02Label, ''),
         @cLottableLabel03 = IsNULL(Lottable03Label, ''),
         @cLottableLabel04 = IsNULL(Lottable04Label, ''),
         @cLottableCode = LottableCode
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
         AND SKU = @cSKU

      -- Get UOM
      SELECT @cUOM = PACKUOM3
      FROM dbo.Pack WITH (NOLOCK)
      WHERE Packkey = @cPackkey

      -- Get SKU default UOM
      SET @cSKUDefaultUOM = dbo.fnc_GetSKUConfig( @cSKU, 'RDTDefaultUOM', @cStorer)
      IF @cSKUDefaultUOM = '0'
         SET @cSKUDefaultUOM = ''

      -- If config turned on and skuconfig not setup then prompt error
      IF rdt.RDTGetConfig( @nFunc, 'DisplaySKUDefaultUOM', @cStorer) = '1' AND @cSKUDefaultUOM = ''
      BEGIN
         SET @nErrNo = 64283
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
         IF @nErrNo = 1
            SET @cErrMsg1 = ''

         GOTO Step_12_Fail_SKU
      END

      -- Check SKU default UOM in pack key
      IF @cSKUDefaultUOM <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1
            FROM dbo.Pack P WITH (NOLOCK)
            WHERE PackKey = @cPackKey
               AND @cSKUDefaultUOM IN (P.PackUOM1, P.PackUOM2, P.PackUOM3, P.PackUOM4, P.PackUOM5, P.PackUOM6, P.PackUOM7, P.PackUOM8, P.PackUOM9))
         BEGIN
            SET @nErrNo = 64284
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            --EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64284 ', 'INV SKUDEFUOM'
            GOTO Step_12_Fail_SKU
         END
         SET @cUOM = @cSKUDefaultUOM

         -- Get UOM divider
         SET @nUOM_Div = 0
         SELECT @nUOM_Div =
         CASE
               WHEN @cSKUDefaultUOM = PackUOM1 THEN CaseCnt
               WHEN @cSKUDefaultUOM = PackUOM2 THEN InnerPack
               WHEN @cSKUDefaultUOM = PackUOM3 THEN QTY
               WHEN @cSKUDefaultUOM = PackUOM4 THEN Pallet
               WHEN @cSKUDefaultUOM = PackUOM5 THEN Cube
               WHEN @cSKUDefaultUOM = PackUOM6 THEN GrossWgt
               WHEN @cSKUDefaultUOM = PackUOM7 THEN NetWgt
               WHEN @cSKUDefaultUOM = PackUOM8 THEN OtherUnit1
               WHEN @cSKUDefaultUOM = PackUOM9 THEN OtherUnit2
            END
         FROM dbo.Pack P WITH (NOLOCK)
         WHERE PackKey = @cPackKey

         IF @nUOM_Div = 0
            SET @nUOM_Div = 1
      END
      ELSE
         SET @nUOM_Div = 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            IF OBJECT_SCHEMA_NAME( OBJECT_ID( @cExtendedInfoSP)) = 'dbo'
            BEGIN
               SET @cExtendedInfo = ''
               SET @cSQL = 'EXEC ' + RTRIM( @cExtendedInfoSP) +
                  ' @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT'
               SET @cSQLParam =
                  '@cReceiptKey   NVARCHAR( 10), ' +
                  '@cPOKey        NVARCHAR( 10), ' +
                  '@cLOC          NVARCHAR( 10), ' +
                  '@cToID         NVARCHAR( 18), ' +
                  '@cLottable01   NVARCHAR( 18), ' +
                  '@cLottable02   NVARCHAR( 18), ' +
                  '@cLottable03   NVARCHAR( 18), ' +
                  '@dLottable04   DATETIME,  ' +
                  '@cStorer       NVARCHAR( 15), ' +
                  '@cSKU          NVARCHAR( 20), ' +
                  '@cExtendedInfo NVARCHAR( 20) OUTPUT'

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cReceiptKey, @cPOKey, @cLOC, @cToID, @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cStorer, @cSKU, @cExtendedInfo OUTPUT
            END
         END
      END

      -- Verify SKU
      IF @cVerifySKU <> ''
      BEGIN
         EXEC rdt.rdt_VerifySKU @nMobile, @nFunc, @cLangCode, @cStorer, @cSKU, 'CHECK',
            @cWeight        OUTPUT,
            @cCube          OUTPUT,
            @cLength        OUTPUT,
            @cWidth         OUTPUT,
            @cHeight        OUTPUT,
            @cInnerPack     OUTPUT,
            @cCaseCount     OUTPUT,
            @cPalletCount   OUTPUT,
            @nErrNo         OUTPUT,
            @cErrMsg        OUTPUT,
            @cVerifySKUInfo OUTPUT

         IF @nErrNo <> 0
         BEGIN
            -- Enable field
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Info'   AND Short = '1') SET @cFieldAttr12 = '' ELSE SET @cFieldAttr12 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Weight' AND Short = '1') SET @cFieldAttr04 = '' ELSE SET @cFieldAttr04 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Cube'   AND Short = '1') SET @cFieldAttr05 = '' ELSE SET @cFieldAttr05 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Length' AND Short = '1') SET @cFieldAttr06 = '' ELSE SET @cFieldAttr06 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Width'  AND Short = '1') SET @cFieldAttr07 = '' ELSE SET @cFieldAttr07 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Height' AND Short = '1') SET @cFieldAttr08 = '' ELSE SET @cFieldAttr08 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Inner'  AND Short = '1') SET @cFieldAttr09 = '' ELSE SET @cFieldAttr09 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Case'   AND Short = '1') SET @cFieldAttr10 = '' ELSE SET @cFieldAttr10 = 'O'
            IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorer AND Code = 'Pallet' AND Short = '1') SET @cFieldAttr11 = '' ELSE SET @cFieldAttr11 = 'O'

            -- Prepare next screen var
            SET @cOutField01 = @cSKU
            SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
            SET @cOutField04 = @cWeight
            SET @cOutField05 = @cCube
            SET @cOutField06 = @cLength
            SET @cOutField07 = @cWidth
            SET @cOutField08 = @cHeight
            SET @cOutField09 = @cInnerPack
            SET @cOutField10 = @cCaseCount
            SET @cOutField11 = @cPalletCount
            SET @cOutField12 = @cVerifySKUInfo

            -- Go to verify SKU screen
            SET @nScn = 3950 -- @nScn + 2
            SET @nStep = 7

            GOTO Quit
         END
      END

      SET @cSKUValidated = '1'

      SELECT TOP 1
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND POKey = CASE WHEN @cPOKey = 'NOPO' THEN POKey ELSE @cPOKey END
         AND SKU = @cSKU
      ORDER BY
         CASE WHEN @cToID = ToID THEN 0 ELSE 1 END,
         CASE WHEN QTYExpected > 0 AND QTYExpected > BeforeReceivedQTY THEN 0 ELSE 1 END,
         ReceiptLineNumber

      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nScn = 3990
         SET @nStep = 11
         GOTO Quit
      END

      -- Disable and default QTY field
      IF rdt.RDTGetConfig( 0, 'ReceiveByPieceDisableQTYField', @cStorer) = '1'
      BEGIN
         SET @cFieldAttr05 = 'O' -- QTY
         SET @cDefaultPieceRecvQTY = '1'
      END
      ELSE
      BEGIN
         -- Get default QTY
         SET @cDefaultPieceRecvQTY = rdt.RDTGetConfig( 0, 'DefaultPieceRecvQTY', @cStorer)
         IF @cDefaultPieceRecvQTY = '0'
            SET @cDefaultPieceRecvQTY = ''
      END

      SELECT
         @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
         @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      AND   SKU        = @cSKU
      AND   ToID       = @cToID
      AND   ToLoc      = @cLoc
      AND   Storerkey  = @cStorer

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nBeforeReceivedQty OUTPUT
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nQtyExpected OUTPUT
      END
      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField12 = @cUOM
      SET @cOutField15 = @cExtendedInfo
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
      SET @cInField05 = @cDefaultPieceRecvQTY

      SET @nStep = 13
      SET @nScn = 6415
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN

      -- Prepare next screen variable
      SET @cOutField01 = @cReceiptkey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cTOID
      SET @cFieldAttr04= ''
      SET @nScn = 1752
      SET @nStep = 3
   END
   GOTO Step_12_Quit

   Step_12_Fail_SKU:
   BEGIN
      SET @cSKU = ''
      SET @cPrevBarcode = ''
      SET @cOutField02 = '' -- SKU
      SET @cBarcode = ''
      SET @cFieldAttr02='O'
      EXEC rdt.rdtSetFocusField @nMobile, V_Barcode -- SKU
      GOTO Quit
   END

   Step_12_Quit:
   BEGIN
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 13. Scn = 6415. qty screen
 TO ID     (field01)
 SKU       (field02)
 SKU       (field11)
 Desc1     (field03)
 Desc2     (field04)
 QTY REC   (field06)
 QTY       (field05, input)
 QTY ON ID (field10)
********************************************************************************/
Step_13:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cQTY = @cInField05 -- QTY
      SET @cBarcode = SUBSTRING( @cBarcode, 1, 2000)
      SET @cSKU = @cBarcode -- SKU

      -- Get UOM
      SELECT @cUOM = PACKUOM3
      FROM dbo.Pack WITH (NOLOCK)
      WHERE Packkey = @cPackkey

      SET @cSKUValidated = '1'

      -- Validate blank QTY
      IF @cQty = '' OR @cQty IS NULL
      BEGIN
         -- Serial No
         IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
         BEGIN
            EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
               @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
               @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
               @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

            IF @nErrNo <> 0
               GOTO Quit

            IF @nMoreSNO = 1
            BEGIN
               -- Go to Serial No screen
               SET @nFromScn = @nScn
               SET @nScn = 4831
               SET @nStep = 9

               GOTO Step_13_Quit
            END
         END

         -- EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '64273 ', 'QTY Required'
         EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY
         GOTO Step_13_Quit
      END

      -- Validate QTY
      IF rdt.rdtIsValidQty( @cQty, 21) = 0
      BEGIN
         SET @nErrNo = 64285
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         SET @nErrNo = 0
         GOTO Step_13_Fail_QTY
      END

      -- Check if max no of decimal is 6
      -- IF master.dbo.RegExIsMatch('^\d{0,10}(\.\d{1,6})?$', RTRIM( @cQty), 1) <> 1   -- (james03)
      IF @nCheckQTYFormat = 1
      BEGIN
         IF rdt.rdtIsValidFormat( @nFunc, @cStorer, 'QTY', @cQTY) = 0
         BEGIN
            SET @nErrNo = 64286
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid format
            SET @cErrMsg1 = @cErrMsg
            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
            IF @nErrNo = 1
               SET @cErrMsg1 = ''

            GOTO Step_13_Fail_QTY
         END
      END
      ELSE
      BEGIN
         -- Check QTY field scanned barcode
         IF LEN( @cQTY) > 7  --KimMun
         BEGIN
            SET @nErrNo = 64265
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
            SET @cErrMsg1 = @cErrMsg
            GOTO Step_13_Fail_QTY
         END
      END

      -- Validate QTY convert to master unit become decimal
      SET @fQTY = CAST( @cQTY AS FLOAT) -- Get UOM QTY (possible key-in as float)
      SET @fQTY = @fQTY * @nUOM_Div     -- Convert to master QTY

      SET @nQTY = CAST( @fQty AS INT) -- Convert float to int
      IF @nQTY <> @fQty               -- Test master QTY in float, should be int
      BEGIN
         SET @nErrNo = 64287
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @cErrMsg1 = @cErrMsg
         GOTO Step_13_Fail_QTY
      END

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToBaseQTY', @cStorer, @cSKU, @nQTY OUTPUT
      END

      -- Validate over receive
      IF @cDisAllowRDTOverReceipt = '1'
      BEGIN
         SELECT
            @nQtyExpected = ISNULL( SUM(QtyExpected), 0),
            @nTotalScanQty = ISNULL( SUM(BeforeReceivedQty), 0)
         FROM dbo.Receiptdetail WITH (NOLOCK)
         WHERE StorerKey = @cStorer
            AND SKU = @cSKU
            AND Receiptkey = @cReceiptKey

         IF @nTotalScanQty + @nQTY > @nQtyExpected
         BEGIN
            SET @nErrNo = 64288
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_13_Fail_QTY
         END
      END

      -- Retain QTY field
      SET @cOutField05 = @cQTY

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         -- (ChewKP04)
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQty,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Quit
      END

      -- Serial No
      IF @cSerialNoCapture IN ('1', '2')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorer, @cSKU, @cSKUDesc, @nQTY, 'CHECK', 'ASN', @cReceiptKey,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '2'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nFromScn = @nScn
            SET @nScn = 4831
            SET @nStep = 9

            GOTO Step_13_Quit
         END
      END

      --(cc01)
      IF @cAutoGotoLotScn = '1'
      BEGIN
         -- Dynamic lottable
         EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
            @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
            @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
            @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
            @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
            @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
            @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
            @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
            @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
            @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
            @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
            @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nMorePage   OUTPUT,
            @nErrNo      OUTPUT,
            @cErrMsg     OUTPUT,
            @cReceiptKey,
            @nFunc

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMorePage = 1 -- Yes
         BEGIN
            -- Go to dynamic lottable screen
            SET @nFromScn = @nScn
            SET @nScn = 3990
            SET @nStep = 11
         END
      END

      -- (james18)
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_PieceReceiving_Confirm -- For rollback or commit only our own transaction

      -- Receive
      EXEC rdt.rdt_PieceReceiving_Confirm
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorer,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPoKey,  -- (ChewKP01)
         @cToLOC        = @cLOC,
         @cToID         = @cTOID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nQty,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = 'OK',
         @cSubreasonCode = '',
         @cReceiptLineNumber = @cReceiptLineNumber OUTPUT,
         @cSerialNo      = @cSerialNo,
         @nSerialQTY     = @nSerialQTY,
         @nBulkSNO       = @nBulkSNO,
         @nBulkSNOQTY    = @nBulkSNOQTY        --MT


      IF @nErrNo <> 0
      BEGIN
         SET @cSKUValidated = '0'
         ROLLBACK TRAN rdt_PieceReceiving_Confirm
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         GOTO Quit
      END
      ELSE
         SET @cSKUValidated = '0'

      IF(ISNULL(rdt.RDTGetConfig( @nFunc, 'ValidatePalletType', @cStorer),'0'))!='0' -- Capture pallet type
      BEGIN
         SELECT
         @cPalletType = C_String1
         FROM RDT.RDTMOBREC (NOLOCK)
         WHERE  Mobile = @nMobile

         IF ISNULL(@cPalletType,'')!=''
         BEGIN
            UPDATE RECEIPTDETAIL SET PalletType = @cPalletType
            WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cReceiptLineNumber
         END
      END

      -- (james04)
      IF @cExtendedUpdateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cReceiptKey, @cPOKey, @cExtASN, @cToLOC, @cToID, ' +
            ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, @nQTY, @nAfterStep, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cReceiptKey  NVARCHAR( 10), ' +
            '@cPOKey       NVARCHAR( 10), ' +
            '@cExtASN      NVARCHAR( 20), ' +
            '@cToLOC       NVARCHAR( 10), ' +
            '@cToID        NVARCHAR( 18), ' +
            '@cLottable01  NVARCHAR( 18), ' +
            '@cLottable02  NVARCHAR( 18), ' +
            '@cLottable03  NVARCHAR( 18), ' +
            '@dLottable04  DATETIME,      ' +
            '@cSKU         NVARCHAR( 20), ' +
            '@nQTY         INT,           ' +
            '@nAfterStep   INT,           ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '
           EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
              @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorer, @cReceiptKey, @cPOKey, @cRefNo, @cLOC, @cToID,
              @cLottable01, @cLottable02, @cLottable03, @dLottable04, @cSKU, 0, @nStep,
              @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cSKUValidated = '0'
            ROLLBACK TRAN rdt_PieceReceiving_Confirm
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN
            GOTO Quit
         END
         ELSE
            SET @cSKUValidated = '0'
      END

      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- (james23)
      SELECT @cBUSR1 = BUSR1
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorer
      AND   Sku = @cSKU

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType   = '2', -- Receiving
         @cUserID       = @cUserName,
         @nMobileNo     = @nMobile,
         @nFunctionID   = @nFunc,
         @cFacility     = @cFacility,
         @cStorerKey    = @cStorer,
         @cLocation     = @cLOC,
         @cID           = @cTOID,
         @cSKU          = @cSku,
         @cUOM          = @cUOM,
         @nQTY          = @nQTY,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPOKey,
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @nStep         = @nStep,
         @cRefNo3       = @cBUSR1,
         @cRefNo2       = @cReceiptLineNumber

      -- Get ToIDQTY
      SELECT @nToIDQTY = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM   dbo.Receiptdetail WITH (NOLOCK)
      WHERE  receiptkey = @cReceiptkey
      AND    toloc = @cLOC
      AND    toid = @cTOID
      AND    Storerkey = @cStorer

      -- Get QTY statistic
      SELECT
         @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0),
         @nQtyExpected = ISNULL( SUM( QtyExpected), 0)
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE Receiptkey = @cReceiptKey
      --AND   POKey      = @cPOKey
      AND   SKU        = @cSKU
      AND   ToID       = @cToID
      AND   ToLoc      = @cLoc
      AND   Storerkey  = @cStorer

      -- Print SKU label
      IF @cSKULabel = '1'
         EXEC rdt.rdt_PieceReceiving_SKULabel @nFunc, @nMobile, @cLangCode, @nStep, @nInputKey, @cStorer, @cFacility, @cPrinter,
            @cReceiptKey,
            @cLOC,
            @cToID,
            @cSKU,
            @nQTY,
            @cLottable01,
            @cLottable02,
            @cLottable03,
            @dLottable04,
            @dLottable05,
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

      -- Convert QTY
      IF @cConvertQTYSP <> '' AND EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConvertQTYSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC ' + RTRIM( @cConvertQTYSP) + ' @cType, @cStorer, @cSKU, @nQTY OUTPUT'
         SET @cSQLParam =
            '@cType   NVARCHAR( 10), ' +
            '@cStorer NVARCHAR( 15), ' +
            '@cSKU    NVARCHAR( 20), ' +
            '@nQTY    INT OUTPUT'
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nBeforeReceivedQty OUTPUT
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nQtyExpected OUTPUT

         -- Get ToIDQTY
         SET @nToIDQTY = 0
         SET @nSKUQTY = 0
         SET @curIDSKU = CURSOR FOR
            SELECT SKU, ISNULL( SUM( BeforeReceivedQty), 0)
            FROM   dbo.Receiptdetail WITH (NOLOCK)
            WHERE  receiptkey = @cReceiptkey
            AND    toloc = @cLOC
            AND    toid = @cTOID
            AND    Storerkey = @cStorer
            GROUP BY SKU
            HAVING SUM( BeforeReceivedQty) > 0
         OPEN @curIDSKU
         FETCH NEXT FROM @curIDSKU INTO @cSKU, @nSKUQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 'ToDispQTY', @cStorer, @cSKU, @nSKUQTY OUTPUT
            SET @nToIDQTY = @nToIDQTY + @nSKUQTY
            FETCH NEXT FROM @curIDSKU INTO @cSKU, @nSKUQTY
         END
      END

      -- (james22)
      IF @cDisAllowRDTOverReceipt = '1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     GROUP BY ReceiptKey
                     HAVING ISNULL( SUM( QtyExpected), 0) = ISNULL( SUM( BeforeReceivedQty), 0)
                     AND    ISNULL( SUM( BeforeReceivedQty), 0) > 0)
         BEGIN
            IF @cBackToASNScnWhenFullyRcv = '1'
            BEGIN
               -- Prepare prev screen var
               SET @cOutField01 = '' -- ReceiptKey
               SET @cOutField02 = @cPOKey
               SET @cOutField03 = '' -- ExtASN

               IF @cRefNo <> ''
                  EXEC rdt.rdtSetFocusField @nMobile, 3 -- Refno
               ELSE
                  EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey

               -- go to previous screen
               SET @nScn = 1750
               SET @nStep = 1

               GOTO Quit
            END
         END
      END

      -- (james27)
      IF @cAfterReceiveGoBackToId = '1'
      BEGIN
         -- Prepare next screen variable
         SET @cOutField01 = @cReceiptkey
         SET @cOutField02 = @cPOKey
         SET @cOutField03 = @cLOC
         SET @cOutField04 = ''

         -- Go to next screen
         SET @nScn = 1752
         SET @nStep = 3

         GOTO Quit
      END

      -- Prep QTY fields
      SET @cOutField02 = @cSKU -- SKU
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' + CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10))

      SET @cVerifySKUInfo = ''   -- (james06)
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Dynamic lottable
      EXEC rdt.rdt_Lottable @nMobile, @nFunc, @cLangCode, @nScn, @nInputKey, @cStorer, @cSKU, @cLottableCode, 'CAPTURE', 'POPULATE', 5, 1,
         @cInField01  OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,
         @cInField02  OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,
         @cInField03  OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,
         @cInField04  OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,
         @cInField05  OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,
         @cInField06  OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT,
         @cInField07  OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT,
         @cInField08  OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT,
         @cInField09  OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT,
         @cInField10  OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT,
         @cInField11  OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12  OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13  OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14  OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15  OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nMorePage   OUTPUT,
         @nErrNo      OUTPUT,
         @cErrMsg     OUTPUT,
         @cReceiptKey,
         @nFunc

      IF @nErrNo <> 0
         GOTO Quit

      IF @nMorePage = 1 -- Yes
      BEGIN
         -- Go to dynamic lottable screen
         SET @nFromScn = @nScn
         SET @nScn = 3990
         SET @nStep = 11
         GOTO Quit
      END
      -- Init next screen var
      SET @cOutField01 = @cTOID
      SET @cOutField03 = '' -- SKUDesc1
      SET @cOutField04 = '' -- SKUDesc2
      SET @cMax = ''
      SET @nScn  = 4033
      SET @nStep = 12
   END
   GOTO Step_13_Quit

   Step_13_Fail_QTY:
   BEGIN
      -- Prepare SKU fields
      SET @cOutField01 = @cToID
      SET @cOutField02 = @cSKU
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc,  1, 20)
      SET @cOutField04 = rdt.rdtFormatString( @cSKUDesc, 21, 20)
      SET @cOutField12 = @cUOM
      SET @cOutField15 = @cExtendedInfo
      SET @cOutField05 = @cDefaultPieceRecvQTY
      SET @cOutField06 = CAST( @nBeforeReceivedQty AS NVARCHAR( 7)) + '/' +  CAST( @nQtyExpected AS NVARCHAR( 7))
      SET @cOutField10 = CAST( @nToIDQTY AS NVARCHAR( 10)) -- To ID QTY
      SET @cInField05 = @cDefaultPieceRecvQTY

      SET @nStep = 13
      SET @nScn = 6415
      GOTO Quit
   END

   Step_13_Quit:
   BEGIN
      GOTO Quit
   END
END
GOTO Quit
/********************************************************************************
Step 98.
********************************************************************************/
Step_98:
BEGIN
   IF @cExtScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtScnSP AND type = 'P')
      BEGIN

         DECLARE  @nPreSCn       INT,
                  @nPreInputKey  INT

         SET @nPreSCn = @nScn
         SET @nPreInputKey = @nInputKey
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cUDF01 OUTPUT, @cUDF02 OUTPUT, @cUDF03 OUTPUT,
            @cUDF04 OUTPUT, @cUDF05 OUTPUT, @cUDF06 OUTPUT,
            @cUDF07 OUTPUT, @cUDF08 OUTPUT, @cUDF09 OUTPUT,
            @cUDF10 OUTPUT, @cUDF11 OUTPUT, @cUDF12 OUTPUT,
            @cUDF13 OUTPUT, @cUDF14 OUTPUT, @cUDF15 OUTPUT,
            @cUDF16 OUTPUT, @cUDF17 OUTPUT, @cUDF18 OUTPUT,
            @cUDF19 OUTPUT, @cUDF20 OUTPUT, @cUDF21 OUTPUT,
            @cUDF22 OUTPUT, @cUDF23 OUTPUT, @cUDF24 OUTPUT,
            @cUDF25 OUTPUT, @cUDF26 OUTPUT, @cUDF27 OUTPUT,
            @cUDF28 OUTPUT, @cUDF29 OUTPUT, @cUDF30 OUTPUT

         IF @nErrNo <> 0
            GOTO Step_98_Fail

         IF @cExtScnSP = 'rdt_1581ExtScn01'
         BEGIN
            IF @nPreSCn = 6413
            BEGIN
               SET @cBarcode = @cUDF01
               SET @cPrevBarcode = @cUDF02
               SET @cSKUValidated = @cUDF03
               SET @nBeforeReceivedQty = @cUDF04
               SET @nQtyExpected = @cUDF05
               SET @nToIDQTY = @cUDF06
               SET @cMax = @cUDF07
            END
         END
         
         GOTO Quit
      END
   END -- Ext scn sp <> ''

   Step_98_Fail:
      GOTO Quit
END -- End step98

/********************************************************************************
Step 99. Scn = Customize
********************************************************************************/
Step_99:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cPalletType = @cInField01

      SET @nAction = 1
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_99_Fail
         END
      END
      IF @cEnableAllLottables = '1'
      BEGIN
         -- Init next screen var
         SET @cOutField01 = @cTOID
         SET @cOutField03 = '' -- SKUDesc1
         SET @cOutField04 = '' -- SKUDesc2
         SET @cMax = ''
         SET @nScn  = 4033
         SET @nStep = 12
         GOTO Quit
      END
      -- Disable lottable
      IF @cSkipLottable01 = '1' SELECT @cFieldAttr01 = 'O', @cInField01 = ''
      IF @cSkipLottable02 = '1' SELECT @cFieldAttr02 = 'O', @cInField02 = ''
      IF @cSkipLottable03 = '1' SELECT @cFieldAttr03 = 'O', @cInField03 = ''
      IF @cSkipLottable04 = '1' SELECT @cFieldAttr04 = 'O', @cInField04 = ''
      
      -- Prep next screen var
      SET @cLottable01 = IsNULL( @cLottable01, '')
      SET @cLottable02 = IsNULL( @cLottable02, '')
      SET @cLottable03 = IsNULL( @cLottable03, '')
      --SET @dLottable04 = IsNULL( @dLottable04, 0)
      SET @cSKU = ''
      SET @cUOM = ''

      SET @cOutField01 = @cLottable01
      SET @cOutField02 = @cLottable02
      SET @cOutField03 = @cLottable03
      -- SET @cOutField04 = CASE WHEN @dLottable04 IS NULL THEN rdt.rdtFormatDate( @dLottable04) END
      SET @cOutField04 = rdt.rdtFormatDate( @dLottable04)

      EXEC rdt.rdtSetFocusField @nMobile, 1 --Lottable01

      -- Go to next screen
      SET @nScn = 1753
      SET @nStep = 4

      -- (james13)
      IF @cSkipLottable = '1'
         GOTO Step_4

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nAction = 3
      IF @cExtendedScreenSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScreenSP AND type = 'P')
         BEGIN
            EXECUTE [RDT].[rdt_1580ExtScnEntry] 
               @cExtendedScreenSP,
               @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorer, @cSuggestedLoc OUTPUT ,@cLOC OUTPUT, @cTOID OUTPUT, @cSKU OUTPUT,
               @cReceiptKey,@cPoKey,'',@cReceiptLineNumber,@cPalletType,
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01  OUTPUT,  
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02  OUTPUT,  
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03  OUTPUT,  
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04  OUTPUT,  
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, 
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, 
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, 
               @nAction, 
               @nAfterScn OUTPUT,  @nAfterStep OUTPUT,
               @nErrNo   OUTPUT, 
               @cErrMsg  OUTPUT
            
            IF @nErrNo <> 0
               GOTO Step_99_Fail
            IF @nAfterStep <> 0
            BEGIN
               SET @nScn = @nAfterScn
               SET @nStep = @nAfterStep
               GOTO Quit
            END
         END
      END
      -- Auto generate ID
      IF @cAutoGenID <> ''
      BEGIN
         EXEC rdt.rdt_PieceReceiving_AutoGenID @nMobile, @nFunc, @nStep, @cLangCode
            ,@cAutoGenID
            ,@cReceiptKey
            ,@cPOKey
            ,@cLOC
            ,@cToID
            ,@cOption
            ,@cAutoID  OUTPUT
            ,@nErrNo   OUTPUT
            ,@cErrMsg  OUTPUT
         IF @nErrNo <> 0
            GOTO Step_4_Fail
      SET @cToID = @cAutoID

      END
      ELSE
      BEGIN
         SET @cToID = ''
         SET @cAutoID = ''
      END

      -- Prepare prev screen var
      SET @cOutField01 = @cReceiptKey
      SET @cOutField02 = @cPOKey
      SET @cOutField03 = @cLOC
      SET @cOutField04 = @cToID

      -- Go to previous screen
      SET @nScn = 1752
      SET @nStep = 3

      -- Enable field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''

   END
   GOTO Quit

   Step_99_Fail:
   BEGIN
      SET @cPalletType = ''
   END
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func = @nFunc,
      Step = @nStep,
      Scn = @nScn,

      Facility  = @cFacility,
      StorerKey = @cStorer,
      -- UserName  = @cUserName,

      V_Receiptkey = @cReceiptkey,
      V_POKey      = @cPOKey,
      V_LOC        = @cLOC,
      V_ID         = @cTOID,
      V_SKU        = @cSKU,
      V_SKUDescr   = @cSKUDesc,
      V_QTY        = @nQTY,
      StorerGroup  = @cStorerGroup,

      V_Lottable01 = @cLottable01,
      V_Lottable02 = @cLottable02,
      V_Lottable03 = @cLottable03,
      V_Lottable04 = @dLottable04,
      V_Lottable05 = @dLottable05,
      V_Lottable06 = @cLottable06,
      V_Lottable07 = @cLottable07,
      V_Lottable08 = @cLottable08,
      V_Lottable09 = @cLottable09,
      V_Lottable10 = @cLottable10,
      V_Lottable11 = @cLottable11,
      V_Lottable12 = @cLottable12,
      V_Lottable13 = @dLottable13,
      V_Lottable14 = @dLottable14,
      V_Lottable15 = @dLottable15,

      V_FromScn    = @nFromScn,
      V_Barcode    = @cBarcode,
      V_Max        = @cMax,
      V_Integer1   = @nUOM_Div,
      V_Integer2   = @nToIDQTY,
      V_Integer3   = @nBeforeReceivedQty,
      V_Integer4   = @nQtyExpected,
      V_Integer5   = @nCheckQTYFormat,
      V_Integer6   = @nNOPOFlag,

      V_String1    = @cTempLottable01,
      V_String2    = @cTempLottable02,
      V_String3    = @cTempLottable03,
      V_String4    = @cTempLottable04,
      V_String5    = @cAutoID,
      V_String6    = @cPrevBarcode,
      V_String7    = @cDisAllowRDTOverReceipt,
      V_String8    = @cDefaultPieceRecvQTY,
      V_String9    = @cUOM,
      V_String10   = @cSkipLottable,
      V_String11   = @cTempLottable06,
      --V_String10   = @nUOM_Div,
      --V_String11   = @nToIDQTY,
      V_String12   = @cTargetDB,
      V_String13   = @cSkipLottable01,
      V_String14   = @cSkipLottable02,
      V_String15   = @cSkipLottable03,
      V_String16   = @cSkipLottable04,
      V_String17   = @cBackToASNScnWhenFullyRcv,
      V_String18   = @cAfterReceiveGoBackToId,
      V_String19   = @cDecodeLabelNo,
      V_String20   = @cExtendedInfo,
      V_String21   = @cExtendedInfoSP,
      V_String22   = @cConvertQTYSP,
      V_String23   = @cVerifySKU,
      V_String24   = @cDispStyleColorSize,
      --V_String25   = @nQtyExpected,
      V_String26   = @cRefNo,
      V_String27   = @cMultiSKUBarcode,
      V_String28   = @cExtendedScreenSP,
      V_String29   = @cExtendedUpdateSP,
      V_String30   = @cAutoGenID,
      V_String31   = @cSKULabel,
      V_String32   = @cExtendedValidateSP,
      V_String33   = @cVerifySKUInfo,
      V_String34   = @cSerialNoCapture,
      V_String35   = @cClosePallet,
      V_String36   = @cDecodeSP,
      V_String37   = @cSKUValidated,
      V_String38   = @cLOCLookupSP, --(yeekung01)
      V_String39   = @cFlowThruScreen,
      V_String40   = @cAutoGotoLotScn, --(cc01)
      V_String41   = @cDecodeLottableSP, --(cc02)
      V_String42   = @cSuggestedLocSP, --(cc03)
      V_String43   = @cClosePalletSP,  --(cc03)  
      V_String44   = @cExtScnSP,
      V_String45   = @cEnableAllLottables,
      V_String46   = @cLottableCode,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO