SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_UpdateTrackNo                                  */  
/* Creation Date: 10-May-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: Update UPS Tracking No  (SOS#171456)                        */  
/*                                                                      */  
/* Called By: Precartonize Packing                                      */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 22-Jul-2010  NJOW     1.1  182440 - Generate UPSP Confirmation No.   */  
/* 05-Jan-2012  NJOW02   1.2  Fix ConsoOrderKey compatibility           */  
/* 10-01-2012   ChewKP   1.3  Standardize ConsoOrderKey Mapping         */  
/*                            (ChewKP01)                                */  
/* 10-Feb-2012  Shong    1.4  Performance Tuning                        */  
/* 14-Mar-2012  NJOW03   1.1  238817-Allow item added to close carton   */  
/*                            generate tracking#                        */  
/* 19-Mar-2012  Ung      1.5  Add RDT compatible message                */  
/* 26-Mar-2012  James    1.3  Restructure the exec statement (james01)  */
/************************************************************************/  
  
CREATE PROC    [dbo].[isp_UpdateTrackNo]  
               @c_PickslipNo   NVARCHAR(10)  
,              @n_cartonno     int  
,              @b_Success      int       OUTPUT  
,              @n_err          int       OUTPUT  
,              @c_errmsg       NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue int,  
           @n_starttcnt int  
  
   DECLARE @c_UPSTrackNo NVARCHAR(20),  
           @c_ServiceLevel NVARCHAR(2),  
           @c_UPSAccNo NVARCHAR(15),  
           @c_SpecialHandling NVARCHAR(1),  
           @c_spgentrack NVARCHAR(30),  
           @c_SQL nvarchar(max),  
           @c_facility NVARCHAR(5),  
           @c_storerkey NVARCHAR(15),  
           @c_OrderKey NVARCHAR(10),  
           @c_ConsoOrderKey NVARCHAR(30)  
  
   DECLARE @c_servicetype NVARCHAR(2),  
           @c_custdunsno NVARCHAR(9),  
           @c_USPSConfirmNo NVARCHAR(22)  

   DECLARE @c_ExecArguments   NVARCHAR(4000), -- (james01)
           @c_ExecArguments2  NVARCHAR(4000)
           
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''  
  
   SET @c_ConsoOrderKey = ''  
   SET @c_OrderKey = ''  
  
   SELECT @c_ConsoOrderKey = ph.ConsoOrderKey,  
          @c_OrderKey = ph.OrderKey  
   FROM   PackHeader ph WITH (NOLOCK)  
   WHERE  ph.PickSlipNo = @c_PickslipNo  
  
   IF ISNULL(RTRIM(@c_ConsoOrderKey),'') <> ''  
   BEGIN  
      SELECT TOP 1 @c_OrderKey = O.OrderKey  
      FROM ORDERDETAIL o WITH (NOLOCK)  
      WHERE o.ConsoOrderKey = @c_ConsoOrderKey  
   END  
  
   SELECT @c_UPSTrackNo = '',  
          @c_USPSConfirmNo = ''  --NJOW03  
  
   SELECT @c_UPSTrackNo = MAX(PD.UPC),  
          @c_USPSConfirmNo = MAX(PD.RefNo2) --NJOW03  
   FROM   PackDetail pd WITH (NOLOCK)  
   WHERE  pd.PickSlipNo = @c_PickslipNo  
   AND    pd.CartonNo   = @n_CartonNo  
  
   --NJOW03  
   IF ISNULL(@c_UPSTrackNo,'') <> ''  
   BEGIN  
      UPDATE PACKDETAIL WITH (ROWLOCK)  
      SET PACKDETAIL.UPC = @c_UPSTrackNo,  
          PACKDETAIL.RefNo2 = @c_USPSConfirmNo  
      WHERE PACKDETAIL.Pickslipno = @c_PickslipNo  
      AND PACKDETAIL.Cartonno = @n_cartonno  
      AND ISNULL(PACKDETAIL.UPC,'') = ''  
   END  
  
   SELECT @c_servicelevel = ORDERS.M_Phone2,  
          @c_UPSAccNo = ORDERS.M_Fax1,  
          @c_SpecialHandling = ORDERS.SpecialHandling,  
          @c_Storerkey = ORDERS.Storerkey,  
          @c_facility = ORDERS.Facility,  
          @c_ServiceType = LEFT(ISNULL(ORDERS.Userdefine01,''),2),  
          @c_CustDUNSNo = LEFT(ISNULL(ORDERS.Userdefine02,''),9)  
   FROM Orders WITH (NOLOCK)  
   WHERE OrderKey = @c_OrderKey  
  
   IF ISNULL(@c_UPSTrackNo,'') = '' AND @c_SpecialHandling IN ('U')  
   BEGIN  
  
      SELECT @c_spgentrack = long  
      FROM CODELKUP (NOLOCK)  
      WHERE CODELKUP.Listname = '3PSType'  
      AND CODELKUP.Code = @c_SpecialHandling  
  
      IF ISNULL(@c_UPSAccNo,'') = ''  
      BEGIN  
        SELECT @c_UPSAccNo = CONVERT(NVARCHAR(15),CODELKUP.Notes)  
        FROM CODELKUP (NOLOCK)  
        WHERE CODELKUP.Listname = '3PShp'  
        AND CODELKUP.Code = @c_SpecialHandling  
        AND CODELKUP.Long = @c_Storerkey  
        AND (CODELKUP.Short = @c_Facility OR ISNULL(CODELKUP.Short,'')='')  
      END  
  
      IF ISNULL(@c_UPSAccNo,'') = ''  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 75601  
         SELECT @c_errmsg = 'No account number in system. Please check WMS order #' + RTRIM(@c_OrderKey) + '. Nothing is generated. (isp_UpdateTrackNo)'  
         GOTO EXIT_PROC  
      END  
  
      SET @c_spgentrack = '[dbo].[' + ISNULL(RTRIM(@c_spgentrack),'') + ']'  
      IF NOT EXISTS(SELECT 1 FROM sys.objects  
                 WHERE object_id = OBJECT_ID(@c_spgentrack)  
                 AND type in (N'P', N'PC'))  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 75602  
         SELECT @c_errmsg = 'Stored Procedure ' + RTRIM(@c_spgentrack) + ' Not Exists in Database(isp_UpdateTrackNo)'  
         GOTO EXIT_PROC  
      END  
  
      SET @c_SQL = N'EXEC ' +  @c_spgentrack + ' @c_UPSAccNo, @c_ServiceLevel, @c_ServiceType, @c_CustDUNSNo, @c_Storerkey, @c_UPSTrackNo OUTPUT, @c_USPSConfirmNo OUTPUT, @b_Success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT'  
      SET @c_ExecArguments  = N' @c_UPSAccNo NVARCHAR(15), @c_ServiceLevel NVARCHAR(2), @c_ServiceType NVARCHAR(2), @c_CustDUNSNo NVARCHAR(9), @c_Storerkey NVARCHAR(15), @c_UPSTrackNo NVARCHAR(20) OUTPUT, ' 
      SET @c_ExecArguments2 = N' @c_USPSConfirmNo NVARCHAR(22) OUTPUT, @b_Success int OUTPUT, @n_err int OUTPUT, @c_errmsg NVARCHAR(250) OUTPUT' 
      SET @c_ExecArguments = RTRIM(@c_ExecArguments) + @c_ExecArguments2
      EXEC sp_ExecuteSql  @c_SQL                                                                                    
                        , @c_ExecArguments                                                                                     
                        , @c_UPSAccNo
                        , @c_ServiceLevel
                        , @c_ServiceType
                        , @c_CustDUNSNo
                        , @c_Storerkey
                        , @c_UPSTrackNo      OUTPUT
                        , @c_USPSConfirmNo   OUTPUT
                        , @b_Success         OUTPUT
                        , @n_err             OUTPUT
                        , @c_errmsg          OUTPUT  

                      
      IF @b_Success <> 1  
      BEGIN  
        SELECT @n_continue = 3  
         SELECT @n_err = 75603  
         SELECT @c_errmsg = 'isp_UpdateTrackNo: ' + RTRIM(ISNULL(@c_errmsg,''))  
         GOTO EXIT_PROC  
      END  
  
      UPDATE PACKDETAIL WITH (ROWLOCK)  
      SET PACKDETAIL.UPC = @c_UPSTrackNo,  
          PACKDETAIL.RefNo2 = @c_USPSConfirmNo  
      WHERE PACKDETAIL.Pickslipno = @c_PickslipNo  
      AND PACKDETAIL.Cartonno = @n_cartonno  
   END  
  
EXIT_PROC:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return    
   BEGIN    
      DECLARE @n_IsRDT INT      
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT      
  
      IF @n_IsRDT = 1  
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
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt  
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UpdateTrackNo'  
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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
      RETURN  
   END  
END

GO