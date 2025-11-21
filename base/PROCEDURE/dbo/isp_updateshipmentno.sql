SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_UpdateShipmentNo                               */
/* Creation Date: 10-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Update UPS Shipment No  (SOS#171456)                        */
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
/* Date         Author     Ver  Purposes                                */
/* 20-Sep-2010  A.AwYoung   1.1  Should get the first UPS Tracking # and*/
/*                               not the last UPS Tracking #. (AAY001)  */
/* 05-Jan-2012  NJOW01      1.2  Fix ConsoOrderkey compatibility        */
/* 10-01-2012   ChewKP      1.3  Standardize ConsoOrderKey Mapping      */
/*                               (ChewKP01)                             */
/* 10-Feb-2012  Shong       1.4  Performance Tuning                     */
/* 19-Mar-2012  Ung         1.5  Add RDT compatible message             */
/************************************************************************/

CREATE PROC    [dbo].[isp_UpdateShipmentNo]
               @c_PickslipNo   NVARCHAR(10)
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
           @c_UPSShipmentNo NVARCHAR(18),
           @c_SpecialHandling NVARCHAR(1),
           @c_spgenshipment NVARCHAR(30),
           @c_SQL nvarchar(max),
           @c_ConsoOrderKey NVARCHAR(30),
           @c_OrderKey      NVARCHAR(10)

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

   IF ISNULL(RTRIM(@c_OrderKey),'') = ''
   BEGIN
    GOTO EXIT_PROC
   END

   SET @c_UPSTrackNo = ''
   SELECT TOP 1
          @c_UPSTrackNo = ISNULL(PD.UPC,'')
   FROM PackDetail pd WITH (NOLOCK)
   WHERE pd.PickSlipNo = @c_PickslipNo

   SELECT TOP 1
          @c_SpecialHandling = ORDERS.SpecialHandling,
          @c_UPSShipmentNo   = ORDERS.M_Fax2
   FROM Orders (NOLOCK)
   WHERE OrderKey = @c_OrderKey

   IF ISNULL(@c_UPSTrackNo,'') <> ''
        --AND @c_SpecialHandling IN ('U','F')
        AND @c_SpecialHandling ='U' --AAY001
   BEGIN
      IF ISNULL(@c_UPSShipmentNo,'') = ''
      BEGIN
         SELECT @c_spgenshipment = CONVERT(NVARCHAR(30),CODELKUP.notes)
         FROM CODELKUP (NOLOCK)
         WHERE CODELKUP.Listname = '3PSType'
         AND CODELKUP.Code = @c_SpecialHandling

         SET @c_spgenshipment = '[dbo].[' + ISNULL(RTRIM(@c_spgenshipment),'') + ']'
         IF NOT EXISTS(SELECT 1 FROM sys.objects
                    WHERE object_id = OBJECT_ID(@c_spgenshipment)
                    AND type in (N'P', N'PC'))
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 75701
            SELECT @c_errmsg = 'Stored Procedure ' + RTRIM(@c_spgenshipment) + ' Not Exists in Database(isp_UpdateShipmentNo)'
            GOTO EXIT_PROC
         END

         SET @c_SQL = N'EXEC ' +  @c_spgenshipment + ' @c_UPSTrackNo, @c_UPSShipmentNo OUTPUT, @b_Success OUTPUT , @n_err OUTPUT, @c_errmsg OUTPUT'

         EXEC sp_ExecuteSQL @c_SQL, N' @c_UPSTrackNo NVARCHAR(20), @c_UPSShipmentNo NVARCHAR(18) OUTPUT, @b_Success int OUTPUT, @n_err int OUTPUT, @c_errmsg NVARCHAR(250) OUTPUT',
                            @c_UPSTrackNo, @c_UPSShipmentNo OUTPUT, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT

         IF @b_Success <> 1
         BEGIN
           SELECT @n_continue = 3
            SELECT @n_err = 75702
            SELECT @c_errmsg = 'isp_UpdateShipmentNo: ' + RTRIM(ISNULL(@c_errmsg,''))
            GOTO EXIT_PROC
         END
      END

      IF ISNULL(RTRIM(@c_ConsoOrderKey),'') = ''
      BEGIN
         UPDATE ORDERS WITH (ROWLOCK)
         SET Userdefine04 = @c_UPSTrackNo,
             M_Fax2 = CASE WHEN ISNULL(M_Fax2,'') = ''
                                     THEN @c_UPSShipmentNo
                                  ELSE M_Fax2
                      END,
             Trafficcop = NULL
         WHERE OrderKey = @c_OrderKey
      END
      ELSE
      BEGIN
       UPDATE ORDERS WITH (ROWLOCK)
         SET Userdefine04 = @c_UPSTrackNo,
             M_Fax2 = CASE WHEN ISNULL(ORDERS.M_Fax2,'') = ''
                                     THEN @c_UPSShipmentNo
                                  ELSE M_Fax2
                      END,
             Trafficcop = NULL
       FROM ORDERS
       JOIN (SELECT DISTINCT OrderKey FROM ORDERDETAIL OD WITH (NOLOCK)
             WHERE OD.ConsoOrderKey = @c_ConsoOrderKey) AS ConsoOrders
             ON ConsoOrders.OrderKey = ORDERS.OrderKey
      END

      --JOIN PACKHEADER (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)
      --WHERE PACKHEADER.Pickslipno = @c_PickslipNo
      --UPDATE ORDERS WITH (ROWLOCK)    
      --SET ORDERS.M_Fax2 = @c_UPSShipmentNo,    
      --    ORDERS.Trafficcop = NULL  
      --FROM ORDERS JOIN PACKHEADER (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey)    
      --FROM PACKHEADER WITH (NOLOCK) --NJOW01    
      --JOIN ORDERDETAIL WITH (NOLOCK) ON ((Packheader.ConsoOrderKey = Orderdetail.consoorderkey AND ISNULL(Orderdetail.Consoorderkey,'')<>'') OR Packheader.Orderkey = Orderdetail.Orderkey ) --NJOW01 -- (ChewKP01)    
      --JOIN Orders ON ( Orderdetail.Orderkey = Orders.Orderkey) --NJOW01    
      --WHERE PACKHEADER.Pickslipno = @c_PickslipNo          
      --AND ISNULL(ORDERS.M_Fax2,'') = ''
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UpdateShipmentNo'
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