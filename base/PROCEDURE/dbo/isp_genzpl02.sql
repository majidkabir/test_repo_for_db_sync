SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GENZPL02                                       */  
/* Creation Date: 14-APR-2023                                           */  
/* Copyright: LFL                                                       */  
/* Written by:CHONGCS                                                   */  
/*                                                                      */  
/* Purpose: WMS-22018 WMS_22018_AU_ADIDAS_Internal_Carton_Label_ZPL     */  
/*                                                                      */  
/* Called By: isp_GenZPL_interface                                      */  
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 14-Apr-2023  CSCHONG   1.0   Devops Scripts Combine                  */  
/* 10-JUL-2023  CSCHONG   1.1   WMS-22018 revised field logic (CS01)    */
/* 22-Sep-2023  CSCHONG   1.2   WMS-23642 revised report logic (CS02)   */
/************************************************************************/  
  
CREATE    PROC isp_GENZPL02 (  
    @c_StorerKey    NVARCHAR( 15)  
   ,@c_Facility     NVARCHAR( 5)  
   ,@c_ReportType   NVARCHAR( 10)  
   ,@c_Param01      NVARCHAR(250)  
   ,@c_Param02      NVARCHAR(250)  
   ,@c_Param03      NVARCHAR(250)  
   ,@c_Param04      NVARCHAR(250)  
   ,@c_Param05      NVARCHAR(250)  
   ,@c_PrnTemplate  NVARCHAR(MAX)  
   ,@c_ZPLCode      NVARCHAR(MAX) OUTPUT  
   ,@b_success      INT           OUTPUT  
   ,@n_err          INT           OUTPUT  
   ,@c_errmsg       NVARCHAR(250) OUTPUT  
    )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_Externorderkey     NVARCHAR( 50) ,  
           @c_company            NVARCHAR( 45) ,  
           @c_trackingNo         NVARCHAR( 40) ,  
           @c_ORDDate            NVARCHAR( 10) ,  
           @n_Continue           INT,  
           @n_starttcnt          INT,  
           @c_trmlogkey          NVARCHAR(20)  
  
  DECLARE @c_field01             NVARCHAR(80) = '',  
          @c_field02             NVARCHAR(80) = '',  
          @c_field03             NVARCHAR(80) = '',  
          @c_field04             NVARCHAR(80) = '',  
          @c_field05             NVARCHAR(80) = '',  
          @c_field06             NVARCHAR(80) = '',  
          @c_field07             NVARCHAR(80) = '',  
          @c_field08             NVARCHAR(80) = '',  
          @c_field09             NVARCHAR(80) = '',  
          @c_field10             NVARCHAR(80) = '',  
          @c_field11             NVARCHAR(150) = '',  
          @c_field12             NVARCHAR(80) = '',  
          @c_field13             NVARCHAR(80) = '',  
          @c_field14             NVARCHAR(80) = '',  
          @c_field15             NVARCHAR(80) = '',  
          @c_field16             NVARCHAR(80) = '',  
          @c_field17             NVARCHAR(150) = '',  
          @c_field18             NVARCHAR(150) = '',  
          @c_field19             NVARCHAR(150) = '',   --CS01  
          @c_field20             NVARCHAR(150) = '',   --CS01  
          @c_field21             NVARCHAR(150) = '',   --CS01  
          @c_field22             NVARCHAR(150) = '',  
          @c_field23             NVARCHAR(150) = '',  
          @c_field24             NVARCHAR(150) = '',  
          @c_field25             NVARCHAR(150) = '',  
          @c_field26             NVARCHAR(150) = '',  
          @c_field27             NVARCHAR(150) = '',  
          @c_field28             NVARCHAR(150) = '',  
          @c_field29             NVARCHAR(150) = '',  
          @c_field30             NVARCHAR(150) = '',  
          @c_field31             NVARCHAR(150) = '',  
  
          @c_orderkey            NVARCHAR(20)  = '',  
          @c_codelen             NVARCHAR(20)  = '',  
          @n_codelen             INT   = 0,  
          @c_long                NVARCHAR(500) = '',    --CS01  
          @c_short               NVARCHAR(10)  = '',    --CS01  
          @c_KeyName             NVARCHAR(18)  = '',    --CS01  
          @c_RunningNo           NVARCHAR(10)  = ''     --CS01   
          , @c_SkipCTNTRACK        NVARCHAR(1)   = 'N'    --CS02   
  
   SELECT @n_starttcnt=@@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_Errmsg = '', @c_ZPLCode = ''  
  
   SELECT @c_codelen = Code  
         ,@c_short   = ISNULL(Short,'')              --CS01  
         ,@c_long    = ISNULL(Long,'')              --CS01  
   FROM codelkup (NOLOCK) WHERE listname ='GENZPL_LEN' AND Storerkey = @c_storerkey  
  
   SET @n_codelen = CAST(@c_codelen AS INT)  
  
   --CS02 S
    IF ISNULL(@c_Param05,'0') = '1'
    BEGIN
      SET @c_SkipCTNTRACK ='Y'

      SELECT @c_field01 = ISNULL(CT.TrackingNo,'')
      FROM dbo.CartonTrack CT WITH (NOLOCK)
      WHERE CT.LabelNo=@c_Param02 AND CT.KeyName = @c_Param04

    END

   --CS02 E
 IF @c_SkipCTNTRACK = 'N'      --CS02 S
 BEGIN  
   --CS01 S  
    IF @c_short ='SSCC'  
    BEGIN  
  
       SET @c_KeyName = @c_Storerkey+'_GENZPL'  
       EXECUTE dbo.nspg_GetKey  
                                 @c_KeyName,  
                                 9 ,  
                                 @c_RunningNo       OUTPUT,  
                                 @b_success         OUTPUT,  
                                 @n_err             OUTPUT,  
                                 @c_errmsg          OUTPUT  
  
      SET @c_trackingNo = @c_long + @c_RunningNo  
  
      SET @c_field01 = dbo.fnc_CalcCheckDigit_M10( @c_trackingNo , 1)  
  
    END  
    ELSE  
    BEGIN  
       SET  @c_field01  = (RIGHT(REPLICATE('0', @n_codelen) + CAST(@c_Param02 AS VARCHAR), @n_codelen))  
    END  
  
   --CS01 E  
 END  --CS02 E 
  
  
   -- Parameter mapping  
  -- SELECT @c_field01      = (RIGHT(REPLICATE('0', @n_codelen) + CAST(@c_Param02 AS VARCHAR), @n_codelen)),--(RIGHT(REPLICATE('0', 18) + CAST(@c_Param02 AS VARCHAR(18)), 18)), --CS01  
   SELECT @c_field02      = OH.UserDefine09,  
          @c_field03      = OH.ExternOrderKey,  
          @c_field04      = OH.ShipperKey,  
          @c_field05      = OH.StorerKey,  
          @c_field06      = pd.CartonNo ,  
          @c_field07      = OH.C_Company,  
          @c_field08      = OH.C_Address1,  
          @c_field09      = OH.C_Address2,                 --CS01  
          @c_field10      = ISNULL(oh.C_State,''), --+ ',' + ISNULL(oh.c_zip,''),    --CS01  
          @c_field11      = OH.C_Country,  
          @c_field12      = s.Company,  
          @c_field13      = s.Address1,  
          @c_field14      = s.Address2,              --CS01  
          @c_field15      = ISNULL(s.State,''),-- + ',' + ISNULL(s.zip,''),   --CS01  
          @c_field16      = s.Country,  
          @c_field17      = PD.LabelNo,  
          @c_orderkey     = OH.OrderKey,  
          @c_Externorderkey = OH.ExternOrderKey,         --CS01 S  
          @c_field18      = ISNULL(oh.c_zip,''),  
          @c_field19      = ISNULL(s.zip,''),  
          @c_field20      = OH.BuyerPO,  
          @c_field21      = OH.UserDefine04               --CS01 E  
         ,@c_field22      = OH.C_City  
         ,@c_field23      = convert(nvarchar(10),pd.adddate,120)  
         ,@c_field24      = convert(nvarchar(10),PH.adddate,120)  
         ,@c_field25      = OH.C_PHONE1  
         ,@c_field26      = CASE WHEN OH.SHIPPERKEY = 'TLI' THEN '004' WHEN OH.SHIPPERKEY = 'TLF' THEN '900' END  
         ,@c_field27      = OH.UserDefine03  
         ,@c_field28      = convert(nvarchar(10),OH.DeliveryDate,120)  
         ,@c_field29      = OH.Notes  
         ,@c_field30      = OH.Notes2  
         ,@c_field31      = s.City  
   FROM ORDERS OH WITH (NOLOCK)  
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey=OH.OrderKey  
   JOIN packdetail pd (nolock) on ph.PickSlipNo = pd.PickSlipNo and ph.StorerKey = pd.StorerKey  
   JOIN STORER s (nolock) on oh.StorerKey = s.StorerKey  
   WHERE ph.PickSlipNo=@c_Param01  
   AND pd.labelno = @c_Param02  
   and pd.CartonNo = @c_Param03  
   AND OH.StorerKey = @c_Param04  
  
  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field01>', RTRIM( ISNULL( @c_field01,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field02>', RTRIM( ISNULL( @c_field02,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field03>', RTRIM( ISNULL( @c_field03,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field04>', RTRIM( ISNULL( @c_field04,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field05>', RTRIM( ISNULL( @c_field05,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field06>', RTRIM( ISNULL( @c_field06,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field07>', RTRIM( ISNULL( @c_field07,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field08>', RTRIM( ISNULL( @c_field08,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field09>', RTRIM( ISNULL( @c_field09,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field10>', RTRIM( ISNULL( @c_field10,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field11>', RTRIM( ISNULL( @c_field11,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field12>', RTRIM( ISNULL( @c_field12,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field13>', RTRIM( ISNULL( @c_field13,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field14>', RTRIM( ISNULL( @c_field14,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field15>', RTRIM( ISNULL( @c_field15,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field16>', RTRIM( ISNULL( @c_field16,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field17>', RTRIM( ISNULL( @c_field17,'')))  
   --CS01 S  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field18>', RTRIM( ISNULL( @c_field18,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field19>', RTRIM( ISNULL( @c_field19,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field20>', RTRIM( ISNULL( @c_field20,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field21>', RTRIM( ISNULL( @c_field21,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field22>', RTRIM( ISNULL( @c_field22,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field23>', RTRIM( ISNULL( @c_field23,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field24>', RTRIM( ISNULL( @c_field24,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field25>', RTRIM( ISNULL( @c_field25,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field26>', RTRIM( ISNULL( @c_field26,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field27>', RTRIM( ISNULL( @c_field27,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field28>', RTRIM( ISNULL( @c_field28,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field29>', RTRIM( ISNULL( @c_field29,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field30>', RTRIM( ISNULL( @c_field30,'')))  
   SET @c_PrnTemplate = REPLACE (@c_PrnTemplate, '<Field31>', RTRIM( ISNULL( @c_field31,'')))  
   --CS01 E  
  
   SET @c_ZPLCode = @c_PrnTemplate  
  
  
IF @c_SkipCTNTRACK = 'N'      --CS02 S
BEGIN  
   INSERT INTO CARTONTRACK (LabelNo, CarrierName, KeyName, TrackingNo, printdata,UDF03)  
    VALUES (@c_Param02, 'Internal', @c_Param04, @c_field01, @c_ZPLCode,@c_Externorderkey)       --CS01  
   --VALUES (@c_Param02, 'Internal', @c_Param04, (@c_Param02+@c_Param03), @c_ZPLCode)  
  
    UPDATE ORDERS WITH (ROWLOCK)  
    SET  TrackingNo = @c_Externorderkey,--@c_orderkey,    --CS01  
         TrafficCop = NULL  
    WHERE Orderkey = @c_Orderkey AND ISNULL(TrackingNo,'') = ''  
  
    IF @@ERROR <> 0  
    BEGIN  
          SELECT @n_Continue = 3  
          SELECT @n_Err = 84032  
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Trackingno Failed. (isp_GENZPL02)'  
    END  
  
    IF EXISTS (SELECT 1 FROM ITFTriggerCOnfig WITH (NOLOCK)  
                        WHERE Tablename = 'WSLABELAVB'  
                        AND Storerkey = @c_Param04  
                        AND SValue = '1')  
    BEGIN  
        IF NOT EXISTS (SELECT 1 FROM TransmitLog2 (NOLOCK)  
                            WHERE TableName = 'WSLABELAVB'  
                            AND Key1 = @c_Param01  
                            AND Key2 = @c_Param03  
                            AND Key3 = @c_Param04)  
        BEGIN  
  
               SELECT @b_success = 1  
               EXECUTE nspg_getkey  
               'TransmitlogKey2'  
               , 10  
               , @c_trmlogkey OUTPUT  
               , @b_success   OUTPUT  
               , @n_err       OUTPUT  
               , @c_errmsg    OUTPUT  
  
               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
               END  
               ELSE  
               BEGIN  
                  INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)  
                  VALUES (@c_trmlogkey, 'WSLABELAVB', @c_Param01, @c_Param03, @c_Param04, '0', '')  
               END  
  
  
               IF @@ERROR <> 0 OR @n_continue = 3  
               BEGIN  
                  SELECT @n_Err = 84031  
                  SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Insert Transmitlog2 Failed. (isp_GENZPL02)'  
                  GOTO QUIT_SP  
               END  
  
               SET @n_err = 0  
               EXEC  [dbo].[isp_QCmd_WSTransmitLogInsertAlert]  
                       @c_QCmdClass            = ''  
                     , @c_FrmTransmitlogKey    = @c_trmlogkey  
                     , @c_ToTransmitlogKey     = @c_trmlogkey  
                     , @b_Debug                = 0  
                     , @b_Success              = @b_success OUTPUT  
                     , @n_Err                  = @n_err     OUTPUT  
                     , @c_ErrMsg               = @c_errmsg  OUTPUT  
  
               IF @n_err <> 0  
               BEGIN  
                 SET @n_Continue = 3  
                 GOTO QUIT_SP  
               END  
  
        END  
  
    END  
    END  --CS02 E
Quit_SP:  
  
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GenZPL_interface'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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
  
END

GO