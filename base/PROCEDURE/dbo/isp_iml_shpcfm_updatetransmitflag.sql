SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store Procedure:  isp_IML_SHPCFM_UpdateTransmitFlag                  */    
/* Creation Date: 10-Feb-2011                                           */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose:  SOS#100636 - USA STD EDI SO Confirm Outbound Process       */    
/*           - To retrieve records for Shipment confirmation.           */    
/*                                                                      */    
/* Input Parameters:  @c_Storerkey     - Storerkey                      */    
/*                    @c_Tablename     - Interface Type                 */    
/*                                                                      */    
/* Output Parameters: @b_Success       - Success Flag  = 0              */    
/*                    @n_err           - Error Code    = 0              */    
/*                    @c_errmsg        - Error Message = ''             */    
/*                                                                      */    
/* Usage:  To Update TransmitFlag from 0 to 1 Only when Count in TML3   */    
/*         tally with Count in MBOL for specified Extern MBOL#          */    
/*                                                                      */    
/* Called By:  Scheduler job                                            */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_IML_SHPCFM_UpdateTransmitFlag]    
(    
     @c_Tablename NVARCHAR(30)    
   , @c_StorerKey NVARCHAR(15)    
   , @b_debug     NVARCHAR(1) = '0'    
   , @b_Success   int = 0  OUTPUT    
   , @n_err       int = 0  OUTPUT    
   , @c_errmsg    NVARCHAR(250) = NULL  OUTPUT    
)    
AS    
BEGIN    
   DECLARE @c_ExternMbolKey   NVARCHAR(30),    
           @n_PlannedOrderCnt INT,    
           @n_ShippedOrderCnt INT,    
           @n_UpdatedOrderCnt INT,    
           @n_continue        INT,    
           @n_StartTCnt       INT    
    
   SET @n_continue = 1    
   SET @n_StartTCnt = @@TRANCOUNT    
  
   DECLARE CUR_ExternMBOLKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT MH.EXTERNMBOLKEY    
         ,COUNT(T3.Key1) ShippedOrderCnt    
   FROM dbo.MBOLDetail MD WITH (NOLOCK)    
   JOIN dbo.MBOL MH WITH (NOLOCK) ON  (MD.MBOLKEY = MH.MBOLKEY)    
   JOIN dbo.TransmitLog3 T3 WITH (NOLOCK) ON  (T3.Key1 = MD.OrderKey)    
   WHERE T3.Transmitflag = '0'    
   AND   T3.Tablename = RTRIM(@c_Tablename)    
   AND   T3.Key3 = @c_StorerKey    
   GROUP BY MH.EXTERNMBOLKEY    
    
   IF @b_debug = '1'    
   BEGIN    
      SELECT MH.EXTERNMBOLKEY    
            ,COUNT(T3.Key1) ShippedOrderCnt    
      FROM dbo.MBOLDetail MD WITH (NOLOCK)    
      JOIN dbo.MBOL MH WITH (NOLOCK) ON  (MD.MBOLKEY = MH.MBOLKEY)    
      JOIN dbo.TransmitLog3 T3 WITH (NOLOCK) ON  (T3.Key1 = MD.OrderKey)    
      WHERE T3.Transmitflag = '0'    
      AND   T3.Tablename = RTRIM(@c_Tablename)    
      AND   T3.Key3 = @c_StorerKey    
      GROUP BY MH.EXTERNMBOLKEY    
   END    
    
   OPEN CUR_ExternMBOLKey    
    
   FETCH NEXT FROM CUR_ExternMBOLKey INTO @c_ExternMbolKey, @n_ShippedOrderCnt    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SELECT @n_PlannedOrderCnt = COUNT(DISTINCT MD.OrderKey)    
      FROM dbo.MBOLDetail MD WITH (NOLOCK)    
      JOIN dbo.MBOL MH WITH (NOLOCK) ON  (MD.MBOLKEY = MH.MBOLKEY)    
      WHERE MH.EXTERNMBOLKEY = @c_ExternMbolKey    
    
      IF @n_PlannedOrderCnt = @n_ShippedOrderCnt    
      BEGIN    
         UPDATE dbo.TransmitLog3 WITH (ROWLOCK)    
            SET    Transmitflag = '1'    
         FROM  dbo.TransmitLog3 TL3 WITH (ROWLOCK)    
          JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON  (TL3.Key1 = MD.OrderKey)    
          JOIN dbo.MBOL MB WITH (NOLOCK) ON  (MD.MBOLKEY = MB.MBOLKEY)    
         WHERE  TL3.Tablename = RTRIM(@c_Tablename)    
         AND    TL3.TransmitFlag = '0'    
         AND    TL3.Key3 = @c_StorerKey    
         AND    MB.EXTERNMBOLKEY = @c_ExternMbolKey    
    
         IF @@ERROR = 0    
         BEGIN    
            WHILE @@TRANCOUNT > 0    
               COMMIT TRAN    
         END    
         ELSE    
         BEGIN    
            SELECT @n_continue = 3    
            SELECT @n_err = 68002    
            SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0)) +    
                               ': Update records in TransmitLog3 failed. (isp_IML_SHPCFM_UpdateTransmitFlag)'    
            BREAK    
         END    
    
         SELECT @n_UpdatedOrderCnt = COUNT(TL3.Key1)    
         FROM  dbo.TransmitLog3 TL3 WITH (ROWLOCK)    
          JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON  (TL3.Key1 = MD.OrderKey)    
          JOIN dbo.MBOL MB WITH (NOLOCK) ON  (MD.MBOLKEY = MB.MBOLKEY)    
         WHERE  TL3.Tablename = RTRIM(@c_Tablename)    
         AND    TL3.TransmitFlag = '1'    
         AND    TL3.Key3 = @c_StorerKey    
         AND    MB.EXTERNMBOLKEY = @c_ExternMbolKey    
    
         -- Reversed If Count Not Match...    
         IF @n_UpdatedOrderCnt <> @n_ShippedOrderCnt    
         BEGIN    
            UPDATE dbo.TransmitLog3 WITH (ROWLOCK)    
               SET    Transmitflag = '0'    
            FROM  dbo.TransmitLog3 TL3 WITH (ROWLOCK)    
             JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON  (TL3.Key1 = MD.OrderKey)    
             JOIN dbo.MBOL MB WITH (NOLOCK) ON  (MD.MBOLKEY = MB.MBOLKEY)    
            WHERE  TL3.Tablename = RTRIM(@c_Tablename)    
            AND    TL3.TransmitFlag = '1'    
            AND    TL3.Key3 = @c_StorerKey    
            AND    MB.EXTERNMBOLKEY = @c_ExternMbolKey    
         END    
      END    
  
      FETCH NEXT FROM CUR_ExternMBOLKey INTO @c_ExternMbolKey, @n_ShippedOrderCnt    
   END    
   CLOSE CUR_ExternMBOLKey    
   DEALLOCATE CUR_ExternMBOLKey    
    
QUIT:    
    
   WHILE @@TRANCOUNT < @n_StartTCnt    
      BEGIN TRAN    
    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_IML_SHPCFM_UpdateTransmitFlag'    
    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
END


GO