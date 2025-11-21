SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GenWCSInterface                                */
/* Creation Date: 26-Mar-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  SOS#166765 - WCS Loadplan Interface Trigger                */
/*                                                                      */
/* Called By: Loadplan                                                  */ 
/*                                                                      */
/* Parameters: (Input)                                                  */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_GenWCSInterface]
        @c_Loadkey NVARCHAR(10),     
        @b_success  Int OUTPUT,
        @n_err      Int OUTPUT,
        @c_errmsg   NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_Storerkey NVARCHAR(15),
           @c_Facility  NVARCHAR(5), 
           @c_authority NVARCHAR(1),
           @n_continue  int,
           @n_starttcnt int
        
    SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0
             
    SELECT TOP 1 @c_Facility = O.Facility, 
                 @c_StorerKey = O.StorerKey 
    FROM LoadPlanDetail lpd WITH (NOLOCK)
    JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey 
    WHERE lpd.LoadKey = @c_LoadKey
    ORDER BY lpd.LoadLineNumber
      
    EXECUTE nspGetRight 
            @c_Facility,  -- facility
            @c_StorerKey, -- Storerkey
            null,         -- Sku
            'WMSWCSLP',   -- Configkey
            @b_success    output,
            @c_authority  output, 
            @n_err        output,
            @c_errmsg     output

    IF @c_authority = '1' AND @b_success = 1
    BEGIN
        EXEC dbo.ispGenTransmitLog3 'WMSWCSLP', @c_LoadKey, '' , '', ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               GOTO Quit_SP
            END
    END            
    
    IF @c_authority <> '1' AND @b_success = 1
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = 'Unauthorized To Run. Storerconfig WMSWCSLP Is Disabled'
       GOTO Quit_SP
    END
    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GenWCSInterface'
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
END

GO