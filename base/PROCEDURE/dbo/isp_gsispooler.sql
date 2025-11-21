SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_GSISpooler                                     */  
/* Creation Date: 04-Aug-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: SOS#141877 - Batch Print Label in LoadPlan                  */  
/*                       Backgroud process to generate GSI XML files    */  
/*                                                                      */  
/* Called By: SQL Jobs                                                  */  
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.7                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/* 24/11/2009   KKY      1.1  Removed BillofMaterial linkage as system  */  
/*                            cannot determine which packed carton      */  
/*                            belongs to which BOM.                     */  
/*                            Removed linkage to LoadPlanDetail,        */  
/*                            MBOLDetail and replaced with Orders as    */  
/*                            Orders holds Loadkey and MBOLKey.         */  
/*                            (KKY20091124)                             */  
/* 02/12/2009   KKY      1.2  need to re-initialize the @c_FullText     */  
/*                            before writing the next file              */  
/*                            (KKY20091202)                             */  
/* 04/01/2010   LAu      1.3  SOS# 157754 - Delete Temp #TMP_CARTON1    */  
/*                                          before proceed              */  
/* 10/03/2010   NJOW01   1.4  149590 - Scan_and_Pack Printer lookup     */  
/* 19/01/2011   NJOW02   1.5  202944- Printing of secondary GS1 Label   */  
/* 10/06/2011   Leong    1.6  SOS# 217792 - Uncomment @n_sortby = 1     */  
/* 22/03/2011   SHONG01  1.7  Added TCP Printing Features for Bartender */   
/* 05-Dec-2011 NJOW03   1.8  231818-Bartender GSI Script output as CSV */  
/*                            format                                    */  
/* 05-Dec-2011 NJOW04   1.9  231833-Bartender GSI file save location by*/   
/*                            printer lookup                            */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_GSISpooler] (  
   @c_facility NVARCHAR(5) = ''  --optional to run multiple sql job for respective facility or all  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  @n_continue       int,  
            @n_cnt            int,  
            @n_starttcnt      int,  
            @b_success        int,  
            @c_errmsg         NVARCHAR(225),  
            @n_err            int  
  
   DECLARE  @c_loadkey        NVARCHAR(10),  
            @n_rowid          int,  
            @n_rowid2         int,  
            @c_printerid      NVARCHAR(30),  
            @c_BTWPath        NVARCHAR(50),  
            @n_sortby         int,  
            @c_sortbydesc     NVARCHAR(30),  
            @c_userid   NVARCHAR(18),  
            @c_mbolkey        NVARCHAR(10),  
            @c_orderkey       NVARCHAR(10),  
            @c_templateid     NVARCHAR(60),  
            @c_filepath       NVARCHAR(120),  
            @c_filename       NVARCHAR(100),  
            @n_cartonno       int,  
            @c_cartonno       NVARCHAR(5),  
            @c_buyerpo        NVARCHAR(20),  
            @c_storerkey      NVARCHAR(15),  
            @d_adddate        datetime,  
            @c_datetime       NVARCHAR(18),  
            @d_currdate       datetime,  
            @c_labelno        NVARCHAR(20),  
            @c_printerfolder  NVARCHAR(50),  --NJOW01  
            @n_folderexists   int, --NJOW01  
            @c_tempfilepath   NVARCHAR(120), --NJOW01  
            @c_templateid2    NVARCHAR(60),  
            @c_currtemplateid NVARCHAR(60),  
            @c_currPickslipno NVARCHAR(10), --NJOW02  
            @c_UPSTrackNo     NVARCHAR(20), --NJOW02  
            @c_SpecialHandling NVARCHAR(1) --NJOW02  
  
  
   DECLARE  @c_LineText       NVARCHAR(MAX),  --NJOW03  
            @c_FullText       NVARCHAR(MAX),  
            @n_FirstTime      int,  
            @c_WorkFilePath   NVARCHAR(120),  
            @c_MoveFrFilePath NVARCHAR(120),  
            @c_MoveToFilePath NVARCHAR(120),  
            @c_PrnFolderFullPath NVARCHAR(250), --NJOW04  
            @n_WorkFolderExists int --NJOW04  
  
   -- SHONG01           
   DECLARE @c_TCP_Authority NVARCHAR(10),   
           @c_TCP_IP        NVARCHAR(20),  
           @c_TCP_Port      NVARCHAR(10),  
           @c_BatchNo       NVARCHAR(20)                 
  
   SET @c_BatchNo = ABS(CAST(CAST(NEWID() AS VARBINARY(5)) AS Bigint))     
     
   CREATE TABLE #TMP_GSICartonLabel_XML (SeqNo int,                -- Temp table's PrimaryKey  
                                         LineText NVARCHAR(MAX))   -- XML column  --NJOW03  
                                         CREATE INDEX Seq_ind ON #TMP_GSICartonLabel_XML (SeqNo)  
  
   CREATE TABLE #TMP_CARTON1 (buyerpo        NVARCHAR(20) NULL,  
                              dischargeplace NVARCHAR(30) NULL,  
                              userdefine20   NVARCHAR(30) NULL,  
                              orderkey       NVARCHAR(10) NULL,  
                              facility       NVARCHAR(5) NULL,  
                              mbolkey        NVARCHAR(10) NULL,  
                              pickslipno     NVARCHAR(10) NULL,  
                              consigneekey   NVARCHAR(15) NULL,  
                              style          NVARCHAR(20) NULL,  
                              --KKY 20091124  
                              --parentsku NVARCHAR(20) NULL,  
                              cartonno       int,  
                              labelno        NVARCHAR(20) NULL,  
                              deliveryplace  NVARCHAR(30) NULL)  
  
   CREATE TABLE #TMP_CARTON2 (mbolkey        NVARCHAR(10) NULL,  
                              orderkey       NVARCHAR(10) NULL,  
                              dischargeplace NVARCHAR(30) NULL,  
                              cartonno       int,  
                              buyerpo        NVARCHAR(20) NULL,  
                              userdefine20   NVARCHAR(30) NULL,  
                              labelno        NVARCHAR(20) NULL,  
                              deliveryplace  NVARCHAR(30) NULL,  
                              pickslipno     NVARCHAR(10) NULL,  --NJOW02  
                              rowid          int IDENTITY(1,1))  
  
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0  
  
   BEGIN TRAN  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
  
      SELECT IDENTITY(int,1,1) AS rowid, SPL.loadkey, SPL.printerid, SPL.BTWPath, SPL.sortby,  
             SPL.sortbydesc, SPL.userid, MAX(ORDERS.Storerkey) AS storerkey, SPL.adddate, SPL.Facility  
      INTO #TMP_SPOOLER  
      FROM IDS_GSISpooler SPL (NOLOCK)  
      JOIN LOADPLANDETAIL LD (NOLOCK) ON (SPL.Loadkey = LD.Loadkey)  
      JOIN ORDERS (NOLOCK) ON (LD.Orderkey = Orders.Orderkey)  
      WHERE SPL.status = '0'  
      AND (@c_facility = '' OR SPL.Facility = @c_facility)  
      GROUP BY SPL.loadkey, SPL.printerid, SPL.BTWPath, SPL.sortby, SPL.sortbydesc, SPL.userid, SPL.adddate, SPL.Facility  
      ORDER BY SPL.adddate  
  
      UPDATE IDS_GSISpooler WITH (ROWLOCK)  
      SET IDS_GSISPooler.Status = '5'  
      FROM IDS_GSISpooler  
      JOIN #TMP_SPOOLER ON (IDS_GSISpooler.Loadkey = #TMP_SPOOLER.Loadkey  
                        AND IDS_GSISpooler.adddate = #TMP_SPOOLER.adddate  
                        AND IDS_GSISpooler.facility = #TMP_SPOOLER.facility  
                        AND IDS_GSISpooler.printerid = #TMP_SPOOLER.printerid)  
      WHERE IDS_GSISpooler.Status = '0'  
  
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60114  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Table IDS_GSISpooler. (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      END  
  
      SELECT @n_rowid = 0  
      WHILE 1=1  
      BEGIN  
         SET @c_printerid = '' -- SOS# 157754  
         SET ROWCOUNT 1  
         SELECT @n_rowid = rowid, @c_loadkey = loadkey, @c_printerid = printerid, @c_BTWPath = ISNULL(RTRIM(BTWpath),''),  
                @n_sortby = sortby, @c_sortbydesc = sortbydesc, @c_userid = userid, @c_storerkey = storerkey,  
                @d_adddate = adddate, @c_facility = facility  
         FROM #TMP_SPOOLER  
         WHERE rowid > @n_rowid  
         ORDER BY rowid  
  
      SELECT @n_cnt = @@ROWCOUNT  
      SET ROWCOUNT 0  
  
      IF @n_cnt = 0  
      BREAK  
  
      --NJOW01  
      SELECT @c_printerfolder = RTRIM(ISNULL(Long,''))  
      FROM CODELKUP (NOLOCK)  
      WHERE Short = 'REQUIRED'  
      AND Listname = 'PRNFDLKUP'  
      AND Code = @c_printerid  
  
      --NJOW04  
      SELECT @c_PrnFolderFullPath = RTRIM(ISNULL(Description,''))  
      FROM CODELKUP (NOLOCK)  
      WHERE Listname = 'BARPRINTER'  
      AND Code = @c_printerid  
  
      DELETE FROM #TMP_CARTON1 -- LAu, clean last LP label before go for next -- SOS# 157754  
      INSERT INTO #TMP_CARTON1  
-- Modified to removed MBOLDetail and LoadplanDetail table as well as remove grouping by BillofMaterial (KKY20091124)  
/*  
         SELECT DISTINCT ORDERS.BuyerPO, ORDERS.DischargePlace, FACILITY.UserDefine20, ORDERS.OrderKey,  
              FACILITY.Facility, MBOLDETAIL.MbolKey, PACKHEADER.Pickslipno, ORDERS.Consigneekey,  
              SKU.Style, BILLOFMATERIAL.Sku AS ParentSku, PACKDETAIL.Cartonno, PACKDETAIL.Labelno  
      FROM LOADPLANDETAIL WITH (NOLOCK)  
      JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
      JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.Orderkey AND LOADPLANDETAIL.Loadkey = PACKHEADER.Loadkey)  
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
      JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.sku)  
      JOIN FACILITY WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
      JOIN MBOLDETAIL WITH (NOLOCK) ON (ORDERS.MbolKey = MBOLDETAIL.MbolKey AND ORDERS.Orderkey = MBOLDETAIL.Orderkey)  
      JOIN BILLOFMATERIAL WITH (NOLOCK) ON (PACKDETAIL.Storerkey = BILLOFMATERIAL.Storerkey AND PACKDETAIL.Sku = BILLOFMATERIAL.ComponentSku)  
      WHERE LOADPLANDETAIL.Loadkey = @c_loadkey  
*/  
      SELECT DISTINCT ORDERS.BuyerPO, ORDERS.DischargePlace, FACILITY.UserDefine20, ORDERS.OrderKey,  
             FACILITY.Facility, ORDERS.MbolKey, PACKHEADER.Pickslipno, ORDERS.Consigneekey,  
             SKU.Style, PACKDETAIL.Cartonno, PACKDETAIL.Labelno, ORDERS.DeliveryPlace  
      FROM ORDERS WITH (NOLOCK)  
      JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.Orderkey AND ORDERS.Loadkey = PACKHEADER.Loadkey)  
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
      JOIN SKU WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.sku)  
      JOIN FACILITY WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)  
      WHERE ORDERS.Loadkey = @c_loadkey  
  
      DELETE #TMP_CARTON2  
  
      -- SOS# 217792  
      IF @n_sortby = 1 --sort by bill of material  
      BEGIN  
         INSERT #TMP_CARTON2  
         SELECT mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, labelno  
         FROM #TMP_CARTON1  
         GROUP BY mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, parentsku, Pickslipno, labelno  
         ORDER BY parentsku, Pickslipno, cartonno  
      END  
  
      IF @n_sortby = 2 --sort by discrete pickslip no  
      BEGIN  
         INSERT #TMP_CARTON2  
         SELECT mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, labelno, deliveryplace, pickslipno  
         FROM #TMP_CARTON1  
         GROUP BY mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, pickslipno, labelno, deliveryplace, pickslipno  
         ORDER BY pickslipno, cartonno  
      END  
  
      IF @n_sortby = 3 --sort by ship to  
      BEGIN  
         INSERT #TMP_CARTON2  
         SELECT mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, labelno, deliveryplace, pickslipno  
         FROM #TMP_CARTON1  
         GROUP BY mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, consigneekey, pickslipno, labelno, deliveryplace, pickslipno  
         ORDER BY consigneekey, pickslipno, cartonno  
      END  
  
      IF @n_sortby = 4 --sort by style  
      BEGIN  
         INSERT #TMP_CARTON2  
         SELECT mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, labelno, deliveryplace, pickslipno  
         FROM #TMP_CARTON1  
         GROUP BY mbolkey, orderkey, dischargeplace, cartonno, buyerpo, userdefine20, style, Pickslipno, labelno, deliveryplace, pickslipno  
         ORDER BY style, Pickslipno, cartonno  
      END  
  
      SELECT @n_rowid2 = 0  
      WHILE 1=1  
         BEGIN  
  
         SET ROWCOUNT 1  
  
         SELECT @n_rowid2 = rowid, @c_mbolkey=mbolkey, @c_orderkey=orderkey, @c_templateid=dischargeplace, @c_labelno = labelno,  
                @n_cartonno=cartonno, @c_buyerpo=ISNULL(RTRIM(buyerpo),''), @c_filepath=ISNULL(RTRIM(userdefine20),''),  
                @c_templateid2=deliveryplace, @c_CurrPickslipno = pickslipno  
         FROM #TMP_CARTON2  
         WHERE rowid > @n_rowid2  
         ORDER BY rowid  
  
         SELECT @n_cnt = @@ROWCOUNT  
         SET ROWCOUNT 0  
         IF @n_cnt = 0  
            BREAK  
  
         --NJOW02 Start  
        EXEC isp_UpdateTrackNo @c_CurrPickslipno, @n_CartonNo, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
            GOTO QUIT  
         END  
       EXEC isp_UpdateShipmentNo @c_CurrPickslipno, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT  
         IF @b_success <> 1  
         BEGIN  
            SELECT @n_continue = 3  
            GOTO QUIT  
         END  
  
         SELECT @c_UPSTrackNo=MAX(PACKDETAIL.UPC), @c_SpecialHandling = ORDERS.SpecialHandling  
         FROM PACKHEADER (NOLOCK)  
         JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno)  
         JOIN ORDERS (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)  
         WHERE PACKHEADER.Pickslipno = @c_CurrPickslipno  
         AND PACKDETAIL.Cartonno =  @n_CartonNo  
         GROUP BY ORDERS.SpecialHandling  
  
        IF @c_SpecialHandling IN('U','F')  
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
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60118  
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Print 3PS Label. Template ID Not Setup Yet. Pickslip# '+rtrim(@c_CurrPickslipno) +' (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                GOTO QUIT  
              END  
           END  
           ELSE  
           BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60119  
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Print 3PS Label. Track No Is Empty. '+rtrim(@c_CurrPickslipno)+' (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
              GOTO QUIT  
           END  
         END  
         --NJOW02 End  
  
         --NJOW04  
         IF ISNULL(@c_PrnFolderFullPath,'') <> ''  
            SET @c_FilePath = @c_PrnFolderFullPath  
  
         IF ISNULL(RTRIM(@c_templateid),'') = ''  
            SET @c_templateid = 'Generic.btw'  
  
         IF SUBSTRING(@c_BTWPath, LEN(@c_BTWPath), 1) <> '\'  
            SET @c_BTWPath = @c_BTWPath + '\'  
  
         IF SUBSTRING(@c_FilePath, LEN(@c_FilePath), 1) <> '\'  
            SET @c_FilePath = @c_FilePath + '\'  
  
         SET @c_WorkFilePath = @c_FilePath+'working\' --NJOW04  
  
         SET @c_templateid =  RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID)  
  
         IF ISNULL(@c_templateid2,'') <> ''  
            SET @c_templateid2 = RTRIM(@c_BTWPath) + RTRIM(@c_TemplateID2)  
  
         --NJOW01 - Start  
         IF SUBSTRING(@c_printerfolder, LEN(@c_printerfolder), 1) <> '\'  
            SET @c_printerfolder = @c_printerfolder + '\'  
  
         SET @c_tempfilepath = @c_FilePath+@c_printerfolder  
         EXEC isp_FolderExists  
               @c_tempfilepath,  
               @n_folderexists OUTPUT,  
               @b_success Output  
  
         IF @n_folderexists = 1  
            SET @c_FilePath = @c_tempfilepath  
         --NJOW-1 - End  
  
         SET @c_cartonno = CONVERT(char(5),@n_cartonno)  
  
         SET @c_currtemplateid = @c_templateid  
  
         --NJOW04  
         EXEC isp_FolderExists  
               @c_WorkFilePath,  
               @n_WorkFolderExists OUTPUT,  
               @b_success Output  
                 
         IF @n_WorkFolderExists <> 1  
            SET @c_WorkFilePath = @c_FilePath   
  
         GENGS1XML:  
  
         SET @d_currdate = GETDATE()  
         SET @c_datetime = CONVERT(char(8),getdate(),112)+  
                           RIGHT('0'+RTRIM(datepart(hh,@d_currdate)),2)+  
                           RIGHT('0'+RTRIM(datepart(mi,@d_currdate)),2)+  
                           RIGHT('0'+RTRIM(datepart(ss,@d_currdate)),2)+  
                           RIGHT('00'+RTRIM(datepart(ms,@d_currdate)),3)  
  
         --SET @c_Filename = RTRIM(@c_StorerKey) + RTRIM(@c_BuyerPO) + "_" + RTRIM(@c_DateTime) + ".XML"  
  
         IF @c_SpecialHandling IN('U','F') --NJOW02  
            SET @c_Filename = RTRIM(@c_printerid)+'_'+RTRIM(@c_DateTime)+'_'+RTRIM(@c_UPSTrackNo) + ".CSV"  --NJOW04  
         ELSE  
            SET @c_Filename = RTRIM(@c_printerid)+'_'+RTRIM(@c_DateTime)+'_'+RTRIM(@c_labelno) + ".CSV"  --NJOW04   
  
         SET @c_MoveFrFilePath = @c_WorkFilePath+@c_filename --NJOW04  
         SET @c_MoveToFilePath = @c_FilePath+@c_filename  
  
         TRUNCATE TABLE #TMP_GSICartonLabel_XML  
         EXEC isp_GSICartonLabel @c_mbolkey, @c_orderkey, @c_currtemplateid, @c_printerid, 'TEMPDB', @c_cartonno, '',  @c_labelno  
  
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
  
         IF @c_TCP_Authority = '1'  
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
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60119  
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Printer ID ('+rtrim(@c_printerid) + ') Not Yet setup TCP IP Address (isp_PrintGS1Label)'   
              GOTO QUIT  
            END  
                         
            INSERT INTO XML_Message( BatchNo, Server_IP, Server_Port, XML_Message, RefNo )  
            SELECT @c_BatchNo, @c_TCP_IP, @c_TCP_Port, LineText, ''  
            FROM #TMP_GSICartonLabel_XML  
            ORDER BY SeqNo  
         END  
         ELSE  
         BEGIN  
          SELECT @n_FirstTime = 1  
          --KKY20091202 need to re-initialize the @c_FullText  
          SELECT @c_FullText = ''  
          --KKY20091202  
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
                SET @c_FullText = @c_FullText + master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)  
   
                SET @c_FullText = @c_FullText + @c_LineText  
   
           FETCH NEXT FROM CUR_WRITEFILE INTO @c_LineText  
          END  
          CLOSE CUR_WRITEFILE  
          DEALLOCATE CUR_WRITEFILE  
   
           EXEC isp_WriteStringToFile  
                @c_FullText,  
                @c_WorkFilePath,  
                @c_Filename,  
                2, -- IOMode 2 = ForWriting ,8 = ForAppending  
                @b_success Output  
   
          IF @b_success <> 1  
          BEGIN  
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60111  
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Writing GSI XML/CSV file. (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
             GOTO QUIT  
          END  
   
          IF @n_WorkFolderExists = 1  --NJOW02  
          BEGIN  
              EXEC isp_MoveFile  
                   @c_MoveFrFilePath OUTPUT,  
                   @c_MoveToFilePath OUTPUT,  
                   @b_success Output  
               
             IF @b_success <> 1  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60112  
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Move GSI XML/CSV file. (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                GOTO QUIT  
             END  
          END  
         END           
  
         IF ISNULL(@c_templateid2,'') <> ''  
         BEGIN  
            SET @c_currtemplateid = @c_templateid2  
            SET @c_templateid2 = ''  
            GOTO GENGS1XML  
         END  
      END --while 2  
  
         UPDATE IDS_GSISpooler WITH (ROWLOCK)  
         SET Status = '9', Editdate = getdate()  
         WHERE loadkey = @c_loadkey  
         AND adddate = @d_adddate  
         AND facility = @c_facility  
         AND printerid = @c_printerid  
  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60113  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Table IDS_GSISpooler. (isp_GSISpooler)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
      END  -- while 1  
   END -- continue  
  
QUIT:  
   -- SHONG01  
   IF EXISTS(SELECT 1 FROM XML_Message xm (NOLOCK)  
             WHERE xm.BatchNo = @c_BatchNo   
             AND   xm.[Status] = '0')  
   BEGIN  
      EXEC isp_TCPProcess @c_BatchNo  
   END  
     
   DROP TABLE #TMP_CARTON1  
   DROP TABLE #TMP_CARTON2  
   DROP TABLE #TMP_GSICartonLabel_XML  
   DROP TABLE #TMP_SPOOLER  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GSISpooler'  
      --RAISERROR @n_err @c_errmsg  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END -- End PROC  

GO