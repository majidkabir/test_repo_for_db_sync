SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_rcm_mb_SGPRHK_ShipITF                          */
/* Creation Date: 13-AUG-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-17707-SG - PRHK - MBOL (RCM) to trigger Shipping info   */
/*                                                                      */
/* Called By: MBOL Dymaic RCM configure at listname 'RCMConfig'         */ 
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
/* 16-AUG-2021  CSCHONG   1.1   WMS-17707 revised logic (CS01)          */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_rcm_mb_SGPRHK_ShipITF]
   @c_Mbolkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_Facility                        NVARCHAR(5),
           @c_storerkey                       NVARCHAR(15),
           @c_Orderkey                        NVARCHAR(20),
           @c_GetStorerkey                    NVARCHAR(20),
           @c_MBVessel                        NVARCHAR(60),  
           @d_ArrivalDateFinalDestination     DATETIME,
           @d_DepartureDate                   DATETIME,
           @d_ArrivalDate                     DATETIME   
        
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT TOP 1 @c_Facility = Facility,
                @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE Mbolkey = @c_Mbolkey    

  IF EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK)  
  WHERE StorerKey = @c_StorerKey  
  AND ConfigKey = 'MBRCMLOG'  
  AND SValue = '1')  
  BEGIN 

      SELECT @c_MBVessel = MB.Vessel
            ,@d_ArrivalDateFinalDestination = MB.ArrivalDateFinalDestination
            ,@d_DepartureDate = MB.DepartureDate
            ,@d_ArrivalDate = MB.ArrivalDate
      FROM MBOL MB WITH (NOLOCK)  
      WHERE MB.MbolKey = @c_Mbolkey 



      IF ISNULL(@c_MBVessel,'') = ''
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'Vessel/Flight information is required. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END 

      IF CONVERT(NVARCHAR(10), @d_ArrivalDateFinalDestination, 103) = '01/01/1900' OR @d_ArrivalDateFinalDestination IS NULL
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'Estimated Dispatched Date is required. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END

      IF convert(datetime, convert(nvarchar(10), @d_ArrivalDateFinalDestination , 102))  >= convert(datetime, convert(nvarchar(10), @d_DepartureDate , 102)) 
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'Estimated Dispatched Date must be less than ETD. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END
  
      IF CONVERT(NVARCHAR(10), @d_DepartureDate , 103) = '01/01/1900' OR @d_DepartureDate  IS NULL
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'ETD is required. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END


      IF convert(datetime, convert(nvarchar(10), @d_DepartureDate , 102))  < convert(datetime, convert(nvarchar(10), GETDATE() , 102)) + 3
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'ETD date is lesser than requested min date. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END

         IF CONVERT(NVARCHAR(10), @d_ArrivalDate , 103) = '01/01/1900' OR @d_ArrivalDate  IS NULL
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'ETA is required. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END


      IF convert(datetime, convert(nvarchar(10), @d_ArrivalDate , 102))  < convert(datetime, convert(nvarchar(10), @d_DepartureDate , 102)) + 2
      BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 60098
            SELECT @c_errmsg = 'ETA data is lesser than requested min date ETD+2. (isp_rcm_mb_SGPRHK_ShipITF)' 
            GOTO ENDPROC
      END

         IF NOT EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'MBOLRCMLOG'  
                      AND Key1 = @c_Mbolkey AND Key2 = '' AND Key3 = @c_Storerkey )
         BEGIN          

         EXEC dbo.ispGenTransmitLog3 'MBOLRCMLOG', @c_Mbolkey, '', @c_Storerkey, ''  
              , @b_success OUTPUT  
              , @n_err OUTPUT  
              , @c_errmsg OUTPUT  
        
         --IF @b_success = 0
         --    SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_rcm_mb_SGPRHK_ShipITF: ' + rtrim(@c_errmsg)

        IF @b_success = 0  
        BEGIN
           SELECT @n_continue = 3 
           SELECT @n_err = 60098
           SELECT @c_errmsg = RTRIM(@c_errmsg) + ' (isp_rcm_mb_SGPRHK_ShipITF)' 
           GOTO ENDPROC       
        END
     END   --CS01 START
     ELSE IF EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'MBOLRCMLOG'  
                      AND Key1 = @c_Mbolkey AND Key2 = '' AND Key3 = @c_Storerkey AND transmitflag <> '0')
     BEGIN

        BEGIN TRAN

            UPDATE TransmitLog3 with (RowLOck)     
            SET transmitflag = '0', TrafficCop = NULL           
            WHERE TableName = 'MBOLRCMLOG'  
            AND key1 = @c_Mbolkey           
            AND Key3 = @c_Storerkey 
        
              SELECT @n_err = @@ERROR            
              IF @n_err <> 0             
              BEGIN            
                    SELECT @n_continue = 3 
                    --SELECT @n_err = 60098
                    SELECT @c_errmsg = 'Update TransmitLog3 fail. (isp_rcm_mb_SGPRHK_ShipITF)' 
                           
                  IF @@TRANCOUNT >= 1            
                  BEGIN            
                      ROLLBACK TRAN     
                       GOTO ENDPROC       
                  END            
              END            
              ELSE BEGIN            
                  IF @@TRANCOUNT > 0             
                  BEGIN            
                      COMMIT TRAN  
                      GOTO ENDPROC          
                  END            
                  ELSE BEGIN            
                      SELECT @n_continue = 3            
                      ROLLBACK TRAN   
                      GOTO ENDPROC
                  END            
              END   

      END   --CS01 END

  END
     
ENDPROC: 
 
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_rcm_mb_SGPRHK_ShipITF'
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
END -- End PROC

GO