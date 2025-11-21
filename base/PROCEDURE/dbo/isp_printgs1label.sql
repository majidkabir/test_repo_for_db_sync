SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PrintGS1Label                                  */
/* Creation Date: 07-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: SOS#200192 - Reprint Dropid Label (GS1 XML)                 */
/*                                                                      */
/* Called By: Precartonize Pack, Mbol & DropId                          */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 22-Mar-2011  SHONG01  1.1  Added TCP Printing Features for Bartender */
/* 05-Dec-2011  NJOW01   1.2  231818-Bartender GSI Script output as CSV */
/*                            format                                    */
/* 05-Dec-2011  NJOW02   1.3  231833-Bartender GSI file save location by*/
/*                            printer lookup                            */
/* 16-Dec-2011  NJOW03   1.4  229886-US Shipment Request Trigger Points */
/* 16-Dec-2011  Ung      1.5  231812 Incorporate GS1 Secondary Label    */
/*                            Printing on RDT Scan and Pack             */
/* 04-Jan-2012  Shong    1.6  Fixing Bug - Add ConsoOrderKey (SHONG001) */
/* 04-Jan-2012  Ung      1.7  Fix duplicate label for ConsoOrderKey     */
/* 05-Jan-2012  NJOW04   1.8  Fix ConsoOrderkey compatibility           */
/* 10-01-2012   ChewKP   1.9  Standardize ConsoOrderKey Mapping         */
/*                            (ChewKP01)                                */
/* 16-01-2012   ChewKP   2.0  Insert TraceInfo Log to trace Processing  */
/*                            Time (ChewKP02)                           */
/* 23-01-2012   Shong    2.1  Bug Fixing (SHONG002)                     */
/* 08-02-2012   ChewKP   2.2  Output BatchNo, WCS Process (ChewKP03)    */
/* 08-02-2012   ChewKP   2.3  SKIPJACK MasterLPN Template (ChewKP04)    */
/* 15-02-2012   NJOW05   2.4  230376/230377/236488 - UPS Return Label   */
/* 17-02-2012   ChewKP   2.5  RDT Compatible Error Message (ChewKP05)   */
/* 17-02-2012   ChewKP   2.6  Do not Raise Error> Severity 10 (ChewKP06)*/
/* 28-02-2012   ChewKP   2.7  Do not print secondary label when         */
/*                            @c_EtcTemplateID is set (ChewKP07)        */
/* 19-03-2012   ChewKP   2.8  Add AgileProcess Trigger FedEx(ChewKP08)  */
/* 27-03-2012   ChewKP   2.9  Add AgileProcess Trigger UPS  (ChewKP09)  */
/* 05-04-2012   ChewKP   3.0  New Parameter for Reprint Carrier Label   */
/*                            @c_ReprintCarrier = '1' (ChewKP10)        */
/* 07-04-2012   James    3.1  If SP not fired from RDT or WMS then      */
/*                            continue processing (james01)             */
/* 07-04-2012   Ung      3.2  Fix when WCS on and TCP on, only check    */
/*                            TCP printer for TCP part (ung01)          */
/* 10-04-2012   Shong    3.3  Do not Checking Tracking Number for Over  */
/*                            sea shipment                              */
/* 11-04-2012   Shong    3.4  Performance Tuning                        */
/* 13-04-2012   Ung      3.5  Return Agile error                        */
/* 10-08-2012   James    3.6  Get correct orderkey (james02)            */ 
/* 28-05-2012   Ung      3.7  SOS245083 change master and child carton  */
/*                            on get tracking no, print GS1 (ung02)     */
/* 26-09-2012   TING     3.8  TraceInfo change                          */   
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_PrintGS1Label] (
   @c_DropId           NVARCHAR(20) = '',
   @c_PrinterID        NVARCHAR(215) = '',
   @c_BtwPath          NVARCHAR(215) = '',
   @c_PickslipNo       NVARCHAR(10) = '',
   @n_CartonNoParm     int = 0,
   @c_Mbolkey          NVARCHAR(10) = '',
   @b_Success          int = 1  OUTPUT,
   @n_Err              int = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_LabelNo          NVARCHAR(20) = '' ,
   @c_BatchNo          NVARCHAR(20) = '' OUTPUT, -- (ChewKP03)
   @c_WCSProcess       NVARCHAR(10) = '',        -- "Y" for Socket Process (ChewKP03)
   @c_CartonType       NVARCHAR(10) = 'NORMAL',   -- (ung02)
   --@c_EtcTemplateID    NVARCHAR(60) = '', -- (ChewKP04)
   @c_ReprintCarrier   NVARCHAR(1)  = ''  -- (ChewKP10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int,
            @n_cnt            int,
            @n_starttcnt      int

   DECLARE  @c_orderkey       NVARCHAR(10),
            @c_templateid     NVARCHAR(60),
            @c_templateid2    NVARCHAR(60),
            @c_templateid3    NVARCHAR(60),  --NJOW05
            @c_currtemplateid NVARCHAR(60),
            @c_filepath       NVARCHAR(215),
            @c_filename       NVARCHAR(100),
            @n_cartonno       int,
            @c_cartonno       NVARCHAR(5),
            @c_storerkey      NVARCHAR(15),
            @c_datetime       NVARCHAR(18),
            @d_currdate       datetime,
            --@c_labelno        NVARCHAR(20),
            --@c_printerfolder  NVARCHAR(215),
            @n_folderexists   int,
            @c_tempfilepath   NVARCHAR(215),
            @c_Facility       NVARCHAR(5),
            @c_currPickslipno NVARCHAR(10),
            @c_UPSTrackNo     NVARCHAR(20),
            @c_SpecialHandling NVARCHAR(1),
            @c_PH_OrderKey      NVARCHAR(10),
            @c_PH_ConsoOrderKey NVARCHAR(30),
            @c_PH_LoadKey       NVARCHAR(10),
            @c_UPSRTNLBL_Auth NVARCHAR(10),  --NJOW05
            @c_PRNUPSRTNLBL   NVARCHAR(1), --NJOW05
            @n_UPSRTNLblReprint int, --NJOW05
            @c_m_ISOCntryCode NVARCHAR(10) --NJOW04

   DECLARE  @c_LineText       NVARCHAR(MAX),  --NJOW01
            @c_FullText       NVARCHAR(MAX),
            @n_FirstTime      int,
            @c_WorkFilePath   NVARCHAR(215),
            @c_MoveFrFilePath NVARCHAR(215),
            @c_MoveToFilePath NVARCHAR(215),
            @c_PrnFolderFullPath NVARCHAR(250), --NJOW02
            @n_WorkFolderExists int, --NJOW02
            @c_AgileProcess   NVARCHAR(10), -- (ChewKP08)
            @c_AlertMessage   NVARCHAR(255), -- (ChewKP08)
            @n_AgileErr       int, 
            @c_AgileErrMsg    NVARCHAR(215)


   DECLARE @c_NewLineChar NVARCHAR(2)
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) -- (ChewKP08)

   DECLARE @c_ConsoOrderKey NVARCHAR( 30)
    SET @c_ConsoOrderKey = '' -- SHONG001

   -- SHONG01
   DECLARE @c_TCP_Authority NVARCHAR(10),
           @c_TCP_IP        NVARCHAR(20),
           @c_TCP_Port      NVARCHAR(10),
           --@c_BatchNo       NVARCHAR(20), -- (ChewKP03)
           @n_debug         INT -- (ChewKP02)

   -- (ChewKP02)
   SET @n_debug = 1

   DECLARE  @d_starttime    DATETIME,
            @d_endtime      DATETIME,
            @d_step1        DATETIME,
            @d_step2        DATETIME,
            @d_step3        DATETIME,
            @d_step4        DATETIME,
            @d_step5        DATETIME,
            @c_col1         NVARCHAR(20),
            @c_col2         NVARCHAR(20),
            @c_col3         NVARCHAR(20),
            @c_col4         NVARCHAR(20),
            @c_col5         NVARCHAR(20),
            @c_TraceName    NVARCHAR(80),
            @n_LabelPrinted INT,
            @c_GS1BatchNo   NVARCHAR(10),

            @d_step1a        DATETIME,      
            @d_step2a        DATETIME,      
            @d_step3a        DATETIME,      
            @d_step4a        DATETIME,      
            @d_step5a        DATETIME,  
            @n_loopcnt        int  
  
       SET  @n_loopcnt = 0       
       Set  @d_step1 = convert(datetime,'00:00:00:000')  
       Set  @d_step3 = convert(datetime,'00:00:00:000')  
       Set  @d_step4 = convert(datetime,'00:00:00:000')  
       Set  @d_step5 = convert(datetime,'00:00:00:000') 

   SET @c_Col3 = RTRIM(@c_PickslipNo) + CASE WHEN @n_CartonNoParm > 0 THEN '-' + CAST(@n_CartonNoParm AS NVARCHAR(3)) ELSE '' END
   SET @c_Col2 = RTRIM(@c_LabelNo)
   SET @c_Col1 = 'DropID: ' + RTRIM(@c_DropId)
   SET @c_Col4 = 'MBOL#   ' + RTRIM(@c_Mbolkey)

   IF ISNUMERIC(@c_Errmsg) = 1 AND LEN(@c_Errmsg) > 0
      SET @c_GS1BatchNo = @c_Errmsg
   ELSE
   BEGIN
      SET @c_GS1BatchNo = ''
      EXEC isp_GetGS1BatchNo 5,  @c_GS1BatchNo OUTPUT
   END

   SET @d_starttime = getdate()
   SET @c_TraceName = 'isp_PrintGS1Label'
   --SET @d_step1 = GETDATE()
   SET @n_LabelPrinted = 0
   SET @c_AlertMessage = ''
   SET @n_AgileErr = 0
   SET @c_AgileErrMsg = ''

   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   DECLARE @n_IsWMS Int    -- (james01)
   EXECUTE dbo.ispIsWMS @n_IsWMS OUTPUT

   SET @c_BatchNo = ABS(CAST(CAST(NEWID() AS VARBINARY(5)) AS Bigint))

   CREATE TABLE #TMP_GSICartonLabel_XML (SeqNo int,                -- Temp table's PrimaryKey
                                         LineText NVARCHAR(MAX))   -- XML column    --NJOW01
                                         CREATE INDEX Seq_ind ON #TMP_GSICartonLabel_XML (SeqNo)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN


      /*IF ISNULL(@c_BtwPath,'') = ''
      BEGIN
         SELECT @c_BtwPath = NSQLDescrip
         FROM RDT.RDT.NSQLCONFIG WITH (NOLOCK)
         WHERE ConfigKey = 'GS1TemplatePath'
      END*/

--      SELECT @c_printerfolder = RTRIM(ISNULL(Long,''))
--      FROM CODELKUP (NOLOCK)
--      WHERE Short = 'REQUIRED'
--      AND Listname = 'PRNFDLKUP'
--      AND Code = @c_printerid

      --NJOW02
      SELECT @c_PrnFolderFullPath = RTRIM(ISNULL(Description,''))
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'BARPRINTER'
      AND Code = @c_printerid

      IF ISNULL(@c_DropID,'') <> ''
      BEGIN
         DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
                   ISNULL(RTRIM(Facility.UserDefine20),''), PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
                   ORDERS.DeliveryPlace, PackHeader.PickSlipNo
            FROM DropId WITH (NOLOCK)
            JOIN DropIdDetail WITH (NOLOCK) ON ( DropId.DropID = DropIdDetail.DropID )
            JOIN PackDetail WITH (NOLOCK) ON ( DropIdDetail.ChildID = PackDetail.LabelNo )
            JOIN PackHeader WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
            JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = PackHeader.Orderkey
                                           AND Orders.Loadkey = DropId.Loadkey )
            JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
            WHERE DropId.DropId = @c_DropID
              AND DropId.LabelPrinted = 'Y'
              AND DropId.DropIDType = 'C'
            UNION
            SELECT DISTINCT MAX(Orders.OrderKey) AS OrderKey, MAX(Orders.StorerKey), MAX(Orders.Facility), PackDetail.Cartonno,
                      ISNULL(RTRIM(MAX(Facility.UserDefine20)),''),  PackDetail.Labelno, MAX(ORDERS.DischargePlace), MAX(ORDERS.Mbolkey),
                      MAX(ORDERS.DeliveryPlace), PackHeader.PickSlipNo
            FROM DropId WITH (NOLOCK)
            JOIN DropIdDetail WITH (NOLOCK) ON ( DropId.DropID = DropIdDetail.DropID )
            JOIN PackDetail WITH (NOLOCK) ON ( DropIdDetail.ChildID = PackDetail.LabelNo )
            JOIN PackHeader WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
            JOIN ORDERDETAIL WITH (NOLOCK) ON (PackHeader.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey)
            JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = ORDERDETAIL.Orderkey
                                           AND Orders.Loadkey = DropId.Loadkey )
            JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
            WHERE DropId.DropId = @c_DropID
            AND DropId.LabelPrinted = 'Y'
            AND DropId.DropIDType = 'C'
            AND (ORDERDETAIL.ConsoOrderKey <> '' AND ORDERDETAIL.ConsoOrderKey IS NOT NULL)
            AND (PackHeader.ConsoOrderKey  <> '' AND PackHeader.ConsoOrderKey  IS NOT NULL)
            GROUP BY PackHeader.PickSlipNo, PackDetail.Cartonno, PackDetail.Labelno
            ORDER BY Orders.Orderkey, PackDetail.Cartonno

         GOTO OPENCUR
      END

      IF ISNULL(@c_PickSlipNo,'') <> ''
      BEGIN
         SET @c_PH_OrderKey = ''
         SET @c_PH_ConsoOrderKey = ''
         SET @c_PH_LoadKey = ''

         SELECT @c_PH_ConsoOrderKey = ISNULL(PH.ConsoOrderKey, ''),
                @c_PH_OrderKey      = ISNULL(PH.OrderKey,''),
                @c_PH_LoadKey       = ISNULL(PH.LoadKey, '')
         FROM PackHeader ph WITH (NOLOCK)
         WHERE ph.PickSlipNo = @c_PickSlipNo

         IF ISNULL(RTRIM(@c_PH_ConsoOrderKey),'') <> ''
         BEGIN
            DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT
                   MAX(Orders.OrderKey)  AS OrderKey,
                   MAX(Orders.StorerKey) AS StorerKey,
                   MAX(Orders.Facility)  AS Facility,
                   PackDetail.Cartonno,
                   ISNULL(RTRIM(MAX(Facility.UserDefine20)),'') AS UserDefine20,
                   PackDetail.Labelno,
                   MAX(ORDERS.DischargePlace) AS DischargePlace,
                   MAX(ORDERS.Mbolkey) AS Mbolkey,
                   MAX(ORDERS.DeliveryPlace) AS DeliveryPlace,
                   PackHeader.PickSlipNo
            FROM PackHeader WITH (NOLOCK)
               JOIN PackDetail WITH (NOLOCK) ON  (PackHeader.PickSlipNo = PackDetail.PickSlipNo )
               JOIN ORDERDETAIL WITH (NOLOCK) ON (PackHeader.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey)
               JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = ORDERDETAIL.Orderkey )
               JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
               WHERE PackHeader.PickSlipNo = @c_PickSlipNo
               AND (PackDetail.CartonNo = @n_CartonNoParm OR ISNULL(@n_CartonNoParm,0)=0)
            GROUP BY PackDetail.Cartonno,  PackDetail.Labelno, PackHeader.PickSlipNo
            ORDER BY PackDetail.Cartonno

         END -- ISNULL(RTRIM(@c_PH_ConsoOrderKey),'') <> ''
         ELSE IF ISNULL(RTRIM(@c_PH_OrderKey),'') <> ''
         BEGIN
            DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
                   ISNULL(RTRIM(Facility.UserDefine20),''), PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
                   ORDERS.DeliveryPlace, PackHeader.PickSlipNo
            FROM PackHeader WITH (NOLOCK)
            JOIN PackDetail WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
            JOIN ORDERS WITH (NOLOCK) ON ( PackHeader.Orderkey = Orders.Orderkey )
            JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
            WHERE PackHeader.PickSlipNo = @c_PickSlipNo
            AND (PackDetail.CartonNo = @n_CartonNoParm OR ISNULL(@n_CartonNoParm,0)=0)
            ORDER BY PackDetail.Cartonno
         END
         ELSE
         BEGIN
            SELECT @c_Orderkey = MAX(Loadplandetail.OrderKey)
            FROM PickHeader WITH (NOLOCK)
            JOIN LoadplanDetail WITH (NOLOCK) ON (PickHeader.ExternOrderkey = LoadplanDetail.Loadkey)
            WHERE PickHeader.PickHeaderKey = @c_PickSlipNo

            DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
                   ISNULL(RTRIM(Facility.UserDefine20),''), PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
                   ORDERS.DeliveryPlace, PackHeader.PickSlipNo
            FROM PackHeader WITH (NOLOCK)
               JOIN PackDetail WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
               JOIN PickHeader WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PickHeader.Pickheaderkey )
               JOIN LoadplanDetail WITH (NOLOCK) ON (PickHeader.ExternOrderkey = LoadplanDetail.Loadkey)
               JOIN Orders WITH (NOLOCK) ON ( Loadplandetail.Orderkey = Orders.Orderkey )
               JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
               WHERE PackHeader.PickSlipNo = @c_PickSlipNo
               AND (PackDetail.CartonNo = @n_CartonNoParm OR ISNULL(@n_CartonNoParm,0)=0)
               AND Orders.Orderkey = @c_Orderkey
               ORDER BY PackDetail.Cartonno
         END
         GOTO OPENCUR
      END

      IF ISNULL(@c_MBOLKey,'') <> ''
      BEGIN
         /*
         DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
                ISNULL(RTRIM(Facility.UserDefine20),''),  PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
                ORDERS.DeliveryPlace, PackHeader.PickSlipNo
         FROM MBOLDetail WITH (NOLOCK)
         JOIN PackHeader WITH (NOLOCK) ON (MBOLDetail.Orderkey = PackHeader.Orderkey)
         JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
         JOIN Orders WITH (NOLOCK) ON (PackHeader.Orderkey = Orders.Orderkey)
         JOIN Facility WITH (NOLOCK) ON (Orders.Facility = Facility.facility)
         WHERE MBOLDetail.Mbolkey = @c_MBOLKey
         ORDER BY Orders.Orderkey
         */

         --NJOW04
         DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
                   ISNULL(RTRIM(Facility.UserDefine20),''),  PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
                   ORDERS.DeliveryPlace, PackHeader.PickSlipNo
            FROM PackHeader WITH (NOLOCK)
            JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
            JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = PackHeader.Orderkey )
            JOIN MBOLDetail WITH (NOLOCK) ON (Orders.Orderkey = MBOLDetail.Orderkey)
            JOIN Facility WITH (NOLOCK) ON (Orders.Facility = Facility.facility)
            WHERE MBOLDetail.Mbolkey = @c_MBOLKey
            UNION
            SELECT DISTINCT MAX(Orders.OrderKey), MAX(Orders.StorerKey), MAX(Orders.Facility), PackDetail.Cartonno,
                   ISNULL(RTRIM(MAX(Facility.UserDefine20)),''),  PackDetail.Labelno, MAX(ORDERS.DischargePlace), MBOLDetail.Mbolkey,
                MAX(ORDERS.DeliveryPlace), PackHeader.PickSlipNo
            FROM PackHeader WITH (NOLOCK)
            JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
            JOIN ORDERDETAIL WITH (NOLOCK) ON (PackHeader.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey)
            JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = ORDERDETAIL.Orderkey )
            JOIN MBOLDetail WITH (NOLOCK) ON (Orders.Orderkey = MBOLDetail.Orderkey)
            JOIN Facility WITH (NOLOCK) ON (Orders.Facility = Facility.facility)
            WHERE MBOLDetail.Mbolkey = @c_MBOLKey
            AND  (PackHeader.ConsoOrderKey  IS NOT NULL AND PackHeader.ConsoOrderKey <> '')
            AND  (ORDERDETAIL.ConsoOrderKey IS NOT NULL AND ORDERDETAIL.ConsoOrderKey <> '')
            GROUP BY PackHeader.PickSlipNo, PackDetail.Cartonno, PackDetail.Labelno, MBOLDetail.Mbolkey
            ORDER BY Orders.Orderkey, CartonNo

--            SELECT DISTINCT Orders.OrderKey, Orders.StorerKey, Orders.Facility, PackDetail.Cartonno,
--                   ISNULL(RTRIM(Facility.UserDefine20),''),  PackDetail.Labelno, ORDERS.DischargePlace, ORDERS.Mbolkey,
--                   ORDERS.DeliveryPlace, PackHeader.PickSlipNo
--            FROM PackHeader WITH (NOLOCK)
--            JOIN PackDetail WITH (NOLOCK) ON (PackHeader.PickSlipNo = PackDetail.PickSlipNo)
--            JOIN ORDERDETAIL WITH (NOLOCK) ON ((PackHeader.ConsoOrderKey = ORDERDETAIL.ConsoOrderKey AND ISNULL(ORDERDETAIL.ConsoOrderKey,'')<>'') OR PackHeader.Orderkey = ORDERDETAIL.Orderkey ) --NJOW04 -- (ChewKP01)
--            JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = ORDERDETAIL.Orderkey )
--            JOIN MBOLDetail WITH (NOLOCK) ON (Orders.Orderkey = MBOLDetail.Orderkey)
--            JOIN Facility WITH (NOLOCK) ON (Orders.Facility = Facility.facility)
--            WHERE MBOLDetail.Mbolkey = @c_MBOLKey
--          ORDER BY Orders.Orderkey

         GOTO OPENCUR
      END

      IF ISNULL(@c_LabelNo,'') <> ''
      BEGIN
         SELECT TOP 1
            @n_CartonNo = PD.CartonNo,
            @c_PickSlipNo = PH.PickSlipNo,
            @c_DropId = PD.DROPID,  --larry01 
            @c_ConsoOrderKey = ISNULL(PH.ConsoOrderKey,'') -- (ChewKP01) (SHONG002)
         FROM dbo.PackHeader PH WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         WHERE PD.LabelNo = @c_LabelNo

         IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> ''
         BEGIN
         	SET @c_Orderkey = ''
         	
            -- james002 --LARRY Phase 1 and 2  
            SELECT TOP 1      
               @c_Orderkey = ISNULL( OrderKey,'')          
            FROM PICKDETAIL PD WITH(NOLOCK, INDEX(IDX_PICKDETAIL_DROPID))    
            WHERE Dropid = @c_DropId   
  
            --- XXXXX  
            IF ISNULL(RTRIM(@c_Orderkey),'') <> ''  
            BEGIN  
               SELECT TOP 1     
                    @c_Orderkey = ISNULL( ORDERDETAIL.OrderKey,'')        
               FROM ORDERDETAIL WITH (NOLOCK)     
               JOIN ORDERS WITH (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey         
               WHERE ConsoOrderKey = @c_ConsoOrderKey        
               ORDER BY ORDERS.C_FAX2 DESC    
            END  

         	IF ISNULL(RTRIM(@c_Orderkey),'') <> ''
         	BEGIN
               DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT TOP 1
                  Orders.OrderKey, Orders.StorerKey, Orders.Facility, @n_CartonNo,
                  ISNULL(RTRIM(Facility.UserDefine20),''),  @c_LabelNo, ORDERS.DischargePlace, ORDERS.Mbolkey,
                  ORDERS.DeliveryPlace, @c_PickSlipNo
               FROM Orders WITH (NOLOCK)
               JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
               WHERE Orders.OrderKey = @c_Orderkey
         	END
         	ELSE
            BEGIN
               DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT TOP 1
                  Orders.OrderKey, Orders.StorerKey, Orders.Facility, @n_CartonNo,
                  ISNULL(RTRIM(Facility.UserDefine20),''),  @c_LabelNo, ORDERS.DischargePlace, ORDERS.Mbolkey,
                  ORDERS.DeliveryPlace, @c_PickSlipNo
               FROM ORDERDETAIL WITH (NOLOCK)
               JOIN ORDERS WITH (NOLOCK) ON ( Orders.OrderKey = ORDERDETAIL.Orderkey )
               JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
               WHERE ORDERDETAIL.ConsoOrderKey = @c_ConsoOrderKey
            END
         END
         ELSE
         BEGIN
            IF (SELECT COUNT(1) FROM PickHeader(NOLOCK)
                JOIN Orders(NOLOCK) ON (PickHeader.Orderkey = Orders.Orderkey)
                WHERE PickHeader.Pickheaderkey = @c_PickSlipNo) > 0

               SELECT @c_Orderkey = OrderKey
               FROM PickHeader WITH (NOLOCK)
               WHERE PickHeader.PickHeaderKey = @c_PickSlipNo
            ELSE
               SELECT @c_Orderkey = MAX(Loadplandetail.OrderKey)
               FROM PickHeader WITH (NOLOCK)
               JOIN LoadplanDetail WITH (NOLOCK) ON (PickHeader.ExternOrderkey = LoadplanDetail.Loadkey)
               WHERE PickHeader.PickHeaderKey = @c_PickSlipNo

               DECLARE CUR_GS1LABEL CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT Orders.OrderKey, Orders.StorerKey, Orders.Facility, @n_CartonNo,
                   ISNULL(RTRIM(Facility.UserDefine20),''),  @c_LabelNo, ORDERS.DischargePlace, ORDERS.Mbolkey,
                   ORDERS.DeliveryPlace, @c_PickSlipNo
               FROM Orders WITH (NOLOCK)
               JOIN Facility WITH (NOLOCK) ON ( Orders.Facility = Facility.Facility )
               WHERE Orders.OrderKey = @c_OrderKey
         END
      END



      OPENCUR:
      OPEN CUR_GS1LABEL

      -- SET @d_step1 = GETDATE() - @d_step1

      SET @d_step2 = GETDATE()

      FETCH NEXT FROM CUR_GS1LABEL INTO @c_Orderkey, @c_Storerkey, @c_Facility, @n_CartonNo
                                        ,@c_filepath, @c_labelno, @c_templateid, @c_mbolkey, @c_templateid2, @c_CurrPickslipno
      WHILE @@FETCH_STATUS <> - 1
      BEGIN
         -- Do not stop label printing when getting Errors Log into Alert Table
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Order#: ' + ISNULL(RTRIM(@c_Orderkey),'')  +  @c_NewLineChar
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Storer: ' + ISNULL(RTRIM(@c_Storerkey),'')  + @c_NewLineChar
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' PickSlip#: ' + ISNULL(RTRIM(@c_CurrPickslipno),'') + @c_NewLineChar
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Label#: ' + ISNULL(RTRIM(@c_labelno),'') + @c_NewLineChar
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Carton#: ' + CAST(@n_cartonno AS NVARCHAR(5)) + @c_NewLineChar

         -- Agile Process (ChewKP08)
         EXECUTE dbo.nspGetRight
         @c_facility,   -- facility
         @c_Storerkey,  -- Storerkey
         NULL,          -- Sku
         'AgileProcess',-- Configkey
         @b_success    output,
         @c_AgileProcess output,
         @n_err        output,
         @c_errmsg     output


         SELECT @c_templateid3 = '', @c_PRNUPSRTNLBL = '',  @n_UPSRTNLblReprint = 0, @c_UPSRTNLBL_Auth = '0', @c_m_ISOCntryCode = ''   --NJOW05

         SELECT @c_SpecialHandling = ORDERS.SpecialHandling,
                @c_m_ISOCntryCode = ORDERS.M_ISOCntryCode  --NJOW05
         FROM ORDERS (NOLOCK)
         WHERE ORDERS.Orderkey = @c_Orderkey

         DECLARE @c_ShipToCountry NVARCHAR(30)
         SET @c_ShipToCountry = ''

         SELECT @c_ShipToCountry = ISNULL(oi.OrderInfo07,'')
         FROM OrderInfo oi WITH (NOLOCK)
         WHERE oi.OrderKey = @c_Orderkey


         --NJOW05
         IF @c_m_ISOCntryCode = 'RETURN'
         BEGIN
            SET @b_success = 0
            EXECUTE dbo.nspGetRight
               @c_facility,   -- facility
               @c_Storerkey,  -- Storerkey
               NULL,          -- Sku
               'UPSRETURNTRACKING',-- Configkey
               @b_success    output,
               @c_UPSRTNLBL_Auth  output,
               @n_err        output,
               @c_errmsg     output
         END

         IF @c_SpecialHandling IN('U')
         BEGIN
            -- Request tracking no for master, orphan carton, but not for child carton (ung02)
            IF @c_CartonType IN ('MASTER', 'NORMAL')
            BEGIN
               -- (ChewKP09)
               IF LTRIM(RTRIM(@c_AgileProcess)) = '1'
               BEGIN
                  IF @d_step3 IS NULL OR convert(char(11), @d_step3) <>  convert(char(11), GETDATE())
                  SET @d_step3 = GETDATE()
                  EXEC isp1155P_Agile_ShipmentToHold
                         @c_CurrPickslipno
                        ,@n_cartonno
                        ,@c_labelno
                        ,@b_Success        OUTPUT
                        ,@n_AgileErr       OUTPUT
                        ,@c_AgileErrMsg    OUTPUT
                        ,@c_CartonType --(ung02)
                 SET  @d_step3 = GETDATE() - @d_step3
                 IF @n_AgileErr <> 0
                 BEGIN
                    -- Do not stop label printing when getting Errors Log into Alert Table
                    SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_AgileErr AS NVARCHAR(5)) + @c_NewLineChar
                    SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_AgileErrMsg + @c_NewLineChar
   
                    EXECUTE dbo.nspLogAlert
                         @c_ModuleName   = @c_TraceName,
                         @c_AlertMessage = @c_AlertMessage,
                         @n_Severity     = 0,
                         @b_success      = @b_Success OUTPUT,
                         @n_err          = @n_Err OUTPUT,
                         @c_errmsg       = @c_Errmsg OUTPUT
                 END
   
               END
               ELSE
               BEGIN
                  EXEC isp_UpdateTrackNo @c_CurrPickslipno, @n_CartonNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     IF @n_IsRDT = 1 OR @n_IsWMS = 1
                     BEGIN
                        SELECT @n_continue = 3
                        GOTO QUIT
                     END
                  END
   
                  EXEC isp_UpdateShipmentNo @c_CurrPickslipno, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     IF @n_IsRDT = 1 OR @n_IsWMS = 1
                     BEGIN
                        SELECT @n_continue = 3
                        GOTO QUIT
                     END
                  END
               END
            END
         END



        --NJOW05
         IF @c_UPSRTNLBL_Auth = '1'
         BEGIN
            EXEC isp_UpdateUPSRtnTrackNo @c_CurrPickslipno, @n_CartonNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
            IF @b_success <> 1
            BEGIN
               IF @n_IsRDT = 1 OR @n_IsWMS = 1
               BEGIN
                  SELECT @n_continue = 3
                  GOTO QUIT
               END
            END

            SELECT TOP 1 @c_templateid3 = CONVERT(varchar(60),Notes)
            FROM CODELKUP (NOLOCK)
            WHERE Listname = @c_Storerkey
            AND Code = 'UPSRET' + LTRIM(RTRIM(@c_Facility))

            IF ISNULL(@c_templateid3,'') = ''
            BEGIN
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60110
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Print UPS Return Label. Template ID Not Setup Yet. Pickslip# '+rtrim(@c_CurrPickslipno) +' (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '

               IF @n_IsRDT = 1 OR @n_IsWMS = 1
               BEGIN
                  SELECT @n_continue = 3
                  GOTO QUIT
               END
               -- Do not stop label printing when getting Errors Log into Alert Table
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

               EXECUTE dbo.nspLogAlert
                   @c_ModuleName   = @c_TraceName,
                   @c_AlertMessage = @c_AlertMessage,
                   @n_Severity     = 0,
                   @b_success      = @b_Success OUTPUT,
                   @n_err          = @n_Err OUTPUT,
                   @c_errmsg       = @c_Errmsg OUTPUT
            END

            SELECT @n_UPSRTNLblReprint = COUNT(1)
            FROM UPSReturnTrackNo(NOLOCK)
            WHERE Pickslipno = @c_CurrPickslipno
            AND Labelno = @c_labelno
            AND Orderkey = @c_Orderkey
            AND Reprint = 'Y'
         END


         SELECT @c_UPSTrackNo=MAX(PACKDETAIL.UPC)
         FROM PACKDETAIL (NOLOCK)
         WHERE PACKDETAIL.Pickslipno = @c_CurrPickslipno
         AND PACKDETAIL.Cartonno =  @n_CartonNo
         /*
         SELECT @c_UPSTrackNo=MAX(PACKDETAIL.UPC), @c_SpecialHandling = MAX(ORDERS.SpecialHandling) --NJOW04
         FROM PACKHEADER (NOLOCK)
         JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)
         JOIN ORDERDETAIL WITH (NOLOCK) ON ((Packheader.ConsoOrderKey = Orderdetail.consoorderkey AND ISNULL(Orderdetail.Consoorderkey,'')<>'') OR Packheader.Orderkey = Orderdetail.Orderkey ) --NJOW04 -- (ChewKP01)
         JOIN Orders WITH (NOLOCK) ON ( Orders.Orderkey = Orderdetail.Orderkey ) --NJOW04
         --JOIN ORDERS (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)
         WHERE PACKHEADER.Pickslipno = @c_CurrPickslipno
         AND PACKDETAIL.Cartonno =  @n_CartonNo      
         --GROUP BY ORDERS.SpecialHandling  --NJOW04      
         */    
      
         --NJOW03      
         IF @c_SpecialHandling IN('X') --AND LTRIM(RTRIM(@c_EtcTemplateID)) = ''  
         BEGIN        
            -- Request tracking no for master, orphan carton, but not for child carton (ung02)
            IF @c_CartonType IN ('MASTER', 'NORMAL')
            BEGIN
               -- (ChewKP08)  
               IF LTRIM(RTRIM(@c_AgileProcess)) = '1'   
               BEGIN  
                  EXEC isp1155P_Agile_ShipmentToHold      
                         @c_CurrPickslipno       
                        ,@n_cartonno      
                        ,@c_labelno          
                        ,@b_Success        OUTPUT   
                        ,@n_AgileErr       OUTPUT   
                        ,@c_AgileErrMsg    OUTPUT  
                        ,@c_CartonType --(ung02)
                          
                 IF @n_AgileErr <> 0   
                 BEGIN
                    -- Do not stop label printing when getting Errors Log into Alert Table
                    SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_AgileErr AS NVARCHAR(5)) + @c_NewLineChar
                    SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_AgileErrMsg + @c_NewLineChar
   
                    EXECUTE dbo.nspLogAlert
                         @c_ModuleName   = @c_TraceName,
                         @c_AlertMessage = @c_AlertMessage,
                         @n_Severity     = 0,
                         @b_success      = @b_Success OUTPUT,
                         @n_err          = @n_Err OUTPUT,
                         @c_errmsg       = @c_Errmsg OUTPUT
                 END
   
               END
               ELSE
               BEGIN
                  EXEC isp_ConnectCarrierService @c_CurrPickslipno, @n_cartonno, @c_labelno,'',@c_SpecialHandling, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                       -- Do not stop label printing when getting Errors Log into Alert Table
                       SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
                       SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar
   
                       EXECUTE dbo.nspLogAlert
                            @c_ModuleName   = @c_TraceName,
                            @c_AlertMessage = @c_AlertMessage,
                            @n_Severity     = 0,
                            @b_success      = @b_Success OUTPUT,
                            @n_err          = @n_Err OUTPUT,
                            @c_errmsg       = @c_Errmsg OUTPUT
   
   --                  SELECT @n_continue = 3
   --                  GOTO QUIT
                  END
               END
            END
         END

--         SET  @d_step3 = GETDATE() - @d_step3

         IF @c_SpecialHandling IN('U')
         BEGIN
            IF ISNULL(@c_UPSTrackNo,'') <> ''
            BEGIN
               IF ISNULL(@c_templateid,'') = ''
               BEGIN
                   SELECT @c_templateid = CONVERT(char(60),CODELKUP.notes2)
                   FROM CODELKUP (NOLOCK)
                    WHERE CODELKUP.Listname = '3PSType'
                    AND CODELKUP.Code = @c_SpecialHandling
               END
               IF ISNULL(@c_templateid,'') = ''
               BEGIN
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60118
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Print 3PS Label. Template ID Not Setup Yet. Pickslip# '+rtrim(@c_CurrPickslipno) +' (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  IF @n_IsRDT = 1 OR @n_IsWMS = 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO QUIT
                  END

                 -- Do not stop label printing when getting Errors Log into Alert Table
                 SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
                 SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

                 EXECUTE dbo.nspLogAlert
                      @c_ModuleName   = @c_TraceName,
                      @c_AlertMessage = @c_AlertMessage,
                      @n_Severity     = 0,
                      @b_success      = @b_Success OUTPUT,
                      @n_err          = @n_Err OUTPUT,
                      @c_errmsg       = @c_Errmsg OUTPUT
              END
            END
            ELSE
            BEGIN
            	IF (@c_ShipToCountry = 'USA' OR @c_ShipToCountry = '') AND @c_CartonType IN ('MASTER', 'NORMAL') --(ung02)
            	BEGIN
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60119
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Print 3PS Label. Track No Is Empty. Pickslip# '+rtrim(@c_CurrPickslipno)+' (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  IF @n_IsRDT = 1 OR @n_IsWMS = 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO QUIT
                  END
                  -- Do not stop label printing when getting Errors Log into Alert Table
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

                  EXECUTE dbo.nspLogAlert
                      @c_ModuleName   = @c_TraceName,
                      @c_AlertMessage = @c_AlertMessage,
                      @n_Severity     = 0,
                      @b_success      = @b_Success OUTPUT,
                      @n_err          = @n_Err OUTPUT,
                      @c_errmsg       = @c_Errmsg OUTPUT
            	END
           END
         END

         -- Master carton 1st label (ung02)
         IF @c_CartonType = 'MASTER'
         BEGIN
            -- Get master template file
            SELECT @c_templateid = LEFT( RTRIM( ISNULL( Long, '')), 60)
            FROM dbo.CodeLKUP WITH (NOLOCK) 
            WHERE Listname = 'TEMPLATEID' 
               AND Code = 'MASTER'
         END

         --NJOW02
         IF ISNULL(@c_PrnFolderFullPath,'') <> ''
            SET @c_FilePath = @c_PrnFolderFullPath

         IF ISNULL(RTRIM(@c_templateid),'') = ''
            SET @c_templateid = 'Generic.btw'
/* (ung02)
         -- (ChewKP04)
         IF ISNULL(RTRIM(@c_EtcTemplateID),'') <> ''
            SET @c_templateid = @c_EtcTemplateID
*/
         -- (ChewKP04)
         --IF SUBSTRING(@c_BTWPath, LEN(@c_BTWPath), 1) <> '\'
         IF SUBSTRING(@c_BTWPath, LEN(RTRIM(@c_BTWPath)), 1) <> '\'
            SET @c_BTWPath = RTRIM(@c_BTWPath) + '\'

         IF SUBSTRING(@c_FilePath, LEN(@c_FilePath), 1) <> '\'
            SET @c_FilePath = @c_FilePath + '\'

         SET @c_WorkFilePath = @c_FilePath+'working\'  --NJOW02

         SET @c_templateid =  RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID)

         IF ISNULL(@c_templateid2,'') <> ''
            SET @c_templateid2 = RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID2)

         --NJOW05
         IF ISNULL(@c_templateid3,'') <> ''
            SET @c_templateid3 = RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID3)

--         IF SUBSTRING(@c_printerfolder, LEN(@c_printerfolder), 1) <> '\'
--            SET @c_printerfolder = @c_printerfolder + '\'
--
--         SET @c_tempfilepath = @c_FilePath+@c_printerfolder
--         EXEC isp_FolderExists
--               @c_tempfilepath,
--               @n_folderexists OUTPUT,
--               @b_success Output
--
--         IF @n_folderexists = 1
--            SET @c_FilePath = @c_tempfilepath

         SET @c_cartonno = CONVERT(char(5),@n_cartonno)

         SET @c_currtemplateid = @c_templateid
         SET @n_WorkFolderExists = 1
         --NJOW02
--         EXEC isp_FolderExists
--               @c_WorkFilePath,
--               @n_WorkFolderExists OUTPUT,
--               @b_success Output
--
--         IF @n_WorkFolderExists <> 1
--            SET @c_WorkFilePath = @c_FilePath

         GENGS1XML:

         IF  (@c_UPSRTNLBL_Auth = '1' AND @n_UPSRTNLblReprint > 0 AND @c_PRNUPSRTNLBL <> 'Y') OR (@c_ReprintCarrier = '1' AND ISNULL(@c_templateid2,'') <> '' )    --NJOW05 -- (ChewKP10)
             GOTO SKIPTONEXTLABEL

         SET @d_step1a = GETDATE()
         
         SET @d_currdate = GETDATE()
         SET @c_datetime = CONVERT(char(8),getdate(),112)+
                           RIGHT('0'+RTRIM(datepart(hh,@d_currdate)),2)+
                           RIGHT('0'+RTRIM(datepart(mi,@d_currdate)),2)+
                           RIGHT('0'+RTRIM(datepart(ss,@d_currdate)),2)+
                           RIGHT('00'+RTRIM(datepart(ms,@d_currdate)),3)
         --SET @c_Filename = RTRIM(@c_StorerKey) + RTRIM(@c_BuyerPO) + "_" + RTRIM(@c_DateTime) + ".XML"
         IF @c_SpecialHandling IN('U')
            IF @c_PRNUPSRTNLBL = 'Y' --NJOW05
               SET @c_Filename = RTRIM(@c_printerid)+'_'+RTRIM(@c_UPSTrackNo)+'_RETURN' + ".CSV"   --NJOW05
            ELSE
               SET @c_Filename = RTRIM(@c_printerid)+'_'+RTRIM(@c_DateTime)+'_'+RTRIM(@c_UPSTrackNo) + ".CSV"   --NJOW02
         ELSE
            SET @c_Filename = RTRIM(@c_printerid)+'_'+RTRIM(@c_DateTime)+'_'+RTRIM(@c_labelno) + ".CSV"   --NJOW02

         SET @c_MoveFrFilePath = @c_WorkFilePath+@c_filename --NJOW02
         SET @c_MoveToFilePath = @c_FilePath+@c_filename

         IF @n_IsRDT = 1
         BEGIN
            DELETE rdt.RDTGSICartonLabel_XML WHERE SPID = @@SPID
            IF @c_PRNUPSRTNLBL = 'Y' --NJOW05
               EXEC isp_GSIReturnLabel @c_CurrPickslipno, @c_cartonno, @c_currtemplateid, @c_printerid
            ELSE
               EXEC isp_GSICartonLabel @c_mbolkey, @c_orderkey, @c_currtemplateid, @c_printerid, '', @c_cartonno, '',  @c_labelno,
                    @c_ConsoOrderKey -- SHONG001
         END
         ELSE
         BEGIN
            TRUNCATE TABLE #TMP_GSICartonLabel_XML
            IF @c_PRNUPSRTNLBL = 'Y' --NJOW05
               EXEC isp_GSIReturnLabel @c_CurrPickslipno, @c_cartonno, @c_currtemplateid, @c_printerid
            ELSE
               EXEC isp_GSICartonLabel @c_mbolkey, @c_orderkey, @c_currtemplateid, @c_printerid, 'TEMPDB', @c_cartonno, '',
                    @c_labelno, @c_ConsoOrderKey -- SHONG001
         END
         SET @n_LabelPrinted = @n_LabelPrinted + 1

         -- SHONG01
         -- Get Printer TCP
         SELECT @b_success = 0
         SET @c_TCP_Authority = '0'
         EXECUTE dbo.nspGetRight
            @c_facility,   -- facility
            @c_Storerkey,  -- Storerkey
            NULL,          -- Sku
            'BartenderTCP',-- Configkey
            @b_success    output,
            @c_TCP_Authority  output,
            @n_err        output,
            @c_errmsg     output


         IF @c_TCP_Authority = '1' OR @c_WCSProcess = 'Y' -- (ChewKP03)
         BEGIN
            IF @c_TCP_Authority = '1' -- (ung01)
            BEGIN
               SET @c_TCP_IP = ''
               SET @c_TCP_Port = ''

               SELECT @c_TCP_IP   = Long,
                      @c_TCP_Port = Short
               FROM CODELKUP c (NOLOCK)
               WHERE c.LISTNAME = 'TCPPrinter'
               AND c.Code = @c_printerid

               IF IsNull(RTRIM(@c_TCP_IP),'') = ''
               BEGIN
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60119
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Printer ID ('+rtrim(@c_printerid) + ') Not Yet setup TCP IP Address (isp_PrintGS1Label)'
                  IF @n_IsRDT = 1 OR @n_IsWMS = 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO QUIT
                  END
                 -- Do not stop label printing when getting Errors Log into Alert Table
                 SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
                 SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

                 EXECUTE dbo.nspLogAlert
                      @c_ModuleName   = @c_TraceName,
                      @c_AlertMessage = @c_AlertMessage,
                      @n_Severity     = 0,
                      @b_success      = @b_Success OUTPUT,
                      @n_err          = @n_Err OUTPUT,
                      @c_errmsg       = @c_Errmsg OUTPUT
               END
            END

            IF @n_IsRDT = 1
               INSERT INTO XML_Message( BatchNo, Server_IP, Server_Port, XML_Message, RefNo )
               SELECT @c_BatchNo, @c_TCP_IP, @c_TCP_Port, LineText, ''
               FROM rdt.RDTGSICartonLabel_XML WITH (NOLOCK)
               WHERE SPID = @@SPID
               ORDER BY SeqNo
            ELSE
               INSERT INTO XML_Message( BatchNo, Server_IP, Server_Port, XML_Message, RefNo )
               SELECT @c_BatchNo, @c_TCP_IP, @c_TCP_Port, LineText, ''
               FROM #TMP_GSICartonLabel_XML
               ORDER BY SeqNo

         END
         SET @d_step1 = @d_step1 + (GETDATE() - @d_step1a)
         
         --ELSE -- (ChewKP03)
         IF (@c_TCP_Authority = '0' OR @c_WCSProcess = 'Y') -- (ChewKP03)
            AND @c_PrinterID <> 'WCS'
         BEGIN
            SELECT @n_FirstTime = 1
            SELECT @c_FullText = ''
            SET @d_step3a = GETDATE()

              IF @n_IsRDT = 1
               DECLARE CUR_WRITEFILE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT LineText FROM rdt.RDTGSICartonLabel_XML WITH (NOLOCK)
                  WHERE SPID = @@SPID
                  ORDER BY SeqNo
              ELSE
               DECLARE CUR_WRITEFILE CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT LineText FROM #TMP_GSICartonLabel_XML
                  ORDER BY SeqNo

            OPEN CUR_WRITEFILE
            FETCH NEXT FROM CUR_WRITEFILE INTO @c_LineText
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF @n_FirstTime = 1
                  SET @n_FirstTime = 0
               ELSE
                  SET @c_FullText = @c_FullText + CHAR(13) + CHAR(10)

                  SET @c_FullText = @c_FullText + @c_LineText

               FETCH NEXT FROM CUR_WRITEFILE INTO @c_LineText
            END
            CLOSE CUR_WRITEFILE
            DEALLOCATE CUR_WRITEFILE

            SET @d_step3 = @d_step3 + ( GETDATE() - @d_step3a )
            SET @n_loopcnt =   len(@c_FullText)
            SET  @d_step4a = GETDATE()
            
            EXEC isp_WriteStringToFile
                  @c_FullText,
                  @c_WorkFilePath,
                  @c_Filename,
                  2, -- IOMode 2 = ForWriting ,8 = ForAppending
                  @b_success Output
            SET @d_step4 = @d_step4 + ( GETDATE() - @d_step4a )
            
            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60111
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Writing GSI XML/CSV file. (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               IF @n_IsRDT = 1 OR @n_IsWMS = 1
               BEGIN
                  SELECT @n_continue = 3
                  GOTO QUIT
               END
              -- Do not stop label printing when getting Errors Log into Alert Table
              SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
              SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

              EXECUTE dbo.nspLogAlert
                   @c_ModuleName   = @c_TraceName,
                   @c_AlertMessage = @c_AlertMessage,
                   @n_Severity     = 0,
                   @b_success      = @b_Success OUTPUT,
                   @n_err          = @n_Err OUTPUT,
                   @c_errmsg       = @c_Errmsg OUTPUT
            END

            IF @n_WorkFolderExists = 1  --NJOW02
            BEGIN
               SET @d_Step5a = GETDATE()
               EXEC isp_MoveFile
                     @c_MoveFrFilePath OUTPUT,
                     @c_MoveToFilePath OUTPUT,
                     @b_success Output

               IF @b_success <> 1
               BEGIN
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60112
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Move GSI XML/CSV file. (isp_PrintGS1Label)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  IF @n_IsRDT = 1 OR @n_IsWMS = 1
                  BEGIN
                     SELECT @n_continue = 3
                     GOTO QUIT
                  END
               END
               SET @d_step5 = @d_step5 + ( GETDATE() - @d_step5a )
               
/*
               -- Do not stop label printing when getting Errors Log into Alert Table
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrNo:    ' + CAST(@n_Err AS NVARCHAR(5)) + @c_NewLineChar
               SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ErrMessage: ' + @c_ErrMsg + @c_NewLineChar

               EXECUTE dbo.nspLogAlert
                   @c_ModuleName   = @c_TraceName,
                   @c_AlertMessage = @c_AlertMessage,
                   @n_Severity     = 0,
                   @b_success      = @b_Success OUTPUT,
                   @n_err          = @n_Err OUTPUT,
                   @c_errmsg       = @c_Errmsg OUTPUT
               
*/
            END
         END
         SKIPTONEXTLABEL:  --NJOW05

         SET @c_PRNUPSRTNLBL = '' --NJOW05

         -- Child carton (ung02)
         IF @c_CartonType = 'CHILD'
         BEGIN
            -- Print child carton second label
            IF EXISTS( SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE ORDERS.Orderkey = @c_Orderkey AND SUBSTRING(B_fax1, 4, 1) = 'Y')
            BEGIN
               -- Set exit condition
               SET @c_templateid2 = ''
               SET @c_CartonType = ''
            
               -- Get child carton second label template
               SET @c_currtemplateid = ''
               SELECT @c_currtemplateid = UDF01
               FROM dbo.CodeLKUP WITH (NOLOCK) 
               WHERE ListName = 'TEMPLATEID' 
                  AND StorerKey = @c_Storerkey        

               IF @c_currtemplateid <> ''
                  GOTO GENGS1XML
            END
         END
         ELSE IF ISNULL(@c_templateid2,'') <> ''
         BEGIN
            SET @c_currtemplateid = @c_templateid2
            SET @c_templateid2 = ''
            
            -- 2nd label for Normal or Master carton (ung02)
            IF @c_currtemplateid <> ''
               GOTO GENGS1XML
         END
         ELSE IF @c_UPSRTNLBL_Auth = '1' AND ISNULL(@c_templateid3,'') <> ''  --NJOW05
         BEGIN
            SET @c_currtemplateid = @c_templateid3
            SET @c_PRNUPSRTNLBL = 'Y'
            SET @c_templateid3 = ''

            -- (ung02)
            IF @c_currtemplateid <> ''
               GOTO GENGS1XML
         END

         FETCH NEXT FROM CUR_GS1LABEL INTO @c_Orderkey, @c_Storerkey, @c_Facility, @n_CartonNo
                                           ,@c_filepath, @c_labelno, @c_templateid, @c_mbolkey, @c_templateid2, @c_CurrPickslipno
      END
      CLOSE CUR_GS1LABEL
      DEALLOCATE CUR_GS1LABEL
   END -- continue

   SET @d_step2 = GETDATE() - @d_step2

QUIT:
   -- (ChewKP02)
   IF @n_debug = 1
   BEGIN
      IF @c_Col3 = ''
      BEGIN
         SET @c_Col3 = 'CNT - ' + convert(varchar(10), @n_loopcnt)
      END
      
      SET @d_endtime = GETDATE()
      INSERT INTO TraceInfo VALUES
          (RTRIM(@c_TraceName), @d_starttime, @d_endtime
          ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
          ,CONVERT(CHAR(12),@d_step1,114)
          ,CONVERT(CHAR(12),@d_step2,114)
          ,CONVERT(CHAR(12),@d_step3,114)
          ,CONVERT(CHAR(12),@d_step4,114)
          ,CONVERT(CHAR(12),@d_step5,114)
          ,@c_Col1     -- Col1
          ,@c_Col2     -- Col2
          ,@c_Col3     -- Col3
          ,@c_Col4     -- Col4
          ,RTRIM(@c_GS1BatchNo) + '-' + CAST(@n_LabelPrinted as NVARCHAR(4))) -- Col5
   END

   -- SHONG01
   IF EXISTS(SELECT 1 FROM XML_Message xm (NOLOCK)
             WHERE xm.BatchNo = @c_BatchNo
             AND   xm.[Status] = '0')
   BEGIN
      IF @c_WCSProcess <> 'Y' -- (ung01)
         EXEC isp_TCPProcess @c_BatchNo
   END

   DROP TABLE #TMP_GSICartonLabel_XML

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN

      --DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT


      IF @n_IsRDT = 1 -- (ChewKP05)
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_starttcnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN

         SELECT @b_success = 0
         IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PrintGS1Label'
         --RAISERROR @n_err @c_errmsg
         RAISERROR (@n_err, 10, 1) WITH SETERROR   -- (ChewKP06)
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      IF @c_PrinterID = 'WCS' AND @n_AgileErr <> 0
      BEGIN
         SET @n_Err = @n_AgileErr
         SET @c_ErrMsg = @c_AgileErrMsg
      END
      RETURN
   END
END -- End PROC

GO