SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  msp_RCM_MB_LEVI_UpdatePallet     			            */
/* Creation Date:  13-Dec-2024											                    */
/* Copyright: Maersk WMS												                        */
/* Written by:  USH022                                                  */
/* JIRA TICKET: UWP-27888	                                              */
/* Purpose:  To update PalletDetail.Userdefine01=@MBolKey               */
/*                                                                      */
/* Input Parameters:                                                    */
/*  @c_MbolKey                                                          */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date             Author      Ver         Purposes                    */
/* YYYY-DD-MM       {author}    {ver}		{Comments}					*/
/* 2024-09-13       USH022      V.0		  Initial Implementation          */
/* 2025-01-22       USH022_V1   V.1		  PalletKey association with      */
/*                                        different Mbol orders         */
/************************************************************************/
CREATE    PROCEDURE [dbo].[msp_RCM_MB_LEVI_UpdatePallet]
    @c_MbolKey      NVARCHAR(10),
    @b_Success		  int OUTPUT,
    @n_err			    int OUTPUT,
    @c_errmsg		    NVARCHAR(250) OUTPUT,
    @c_Code			    NVARCHAR(10)
AS
BEGIN
	  SET NOCOUNT ON
    -- SQL 2005 Standard
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE
    @c_StorerKey			NVARCHAR(10),
    @c_Facility				NVARCHAR(20),
	  @c_successFlag			NVARCHAR(1),
	  @n_continue				INT,
	  @n_StartTranCnt			INT,
	  @c_PalletKey		    NVARCHAR(50)

    -- Begin Transaction
	SET @n_continue = 1;
	SELECT @n_StartTranCnt = @@TRANCOUNT;

	BEGIN TRAN;

	IF EXISTS(SELECT 1 FROM MBOL mbol WITH (NOLOCK) WHERE mbol.MBOLKey = @c_MbolKey AND mbol.Status = '9')
	BEGIN
        SELECT @n_continue = 3;
        SELECT @n_err = 63501;
        SELECT @c_errmsg='NSQL' + CONVERT(char(5), @n_err) + ': Userdefine01 cannot be updated for Shipped Status (9).';
        GOTO RETURN_SP;
	END;

	IF NOT EXISTS(SELECT TOP (1) 1 FROM ORDERS O WITH (NOLOCK) WHERE O.MBOLKey = @c_MbolKey)
    BEGIN
        SELECT @n_continue = 3;
        SELECT @n_err = 63501;
        SELECT @c_errmsg='NSQL' + CONVERT(char(5), @n_err) + ': No Orders found with this ShipRef.';
        GOTO RETURN_SP;
    END;

  SELECT TOP 1 @c_StorerKey = O.StorerKey FROM ORDERS O WITH (NOLOCK) WHERE O.MBOLKey = @c_MbolKey
	IF EXISTS (
    select p.ID From pickdetail p (NOLOCK)
    JOIN mboldetail md (NOLOCK) on md.orderkey = p.orderkey
    where md.mbolkey <> @c_MbolKey
    AND p.Storerkey = @c_StorerKey
    AND isnull(p.id,'') <>''
    AND EXISTS (SELECT 1 FROM Pickdetail p1(NOLOCK)
    JOIN mboldetail md1 (NOLOCK) on md1.orderkey = p1.orderkey
    where md1.mbolkey = @c_MbolKey
    AND p.ID = p1.ID)
		)
	BEGIN
		    SELECT @n_continue = 3;
        SELECT @n_err = 63501;
        SELECT @c_errmsg='NSQL' + CONVERT(char(5), @n_err) + ': CaseID belonging to different MBOL found, please split manually.';
        GOTO RETURN_SP;
	END

	DECLARE update_userdefidefine01_cursor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

	SELECT distinct PalletKey from palletdetail (nolock)
	left join pickdetail on palletdetail.caseid = pickdetail.caseid
	left join orders on pickdetail.orderkey = orders.orderkey
	where orders.mbolkey = @c_MbolKey

	OPEN update_userdefidefine01_cursor;
	FETCH NEXT FROM update_userdefidefine01_cursor INTO @c_PalletKey
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE PALLETDETAIL WITH (ROWLOCK) SET UserDefine01 = @c_MbolKey ,trafficcop = null
		where PalletKey = @c_PalletKey;
	FETCH NEXT FROM update_userdefidefine01_cursor INTO @c_PalletKey ;
	END;
	CLOSE update_userdefidefine01_cursor;
	DEALLOCATE update_userdefidefine01_cursor;

	IF (@n_continue = 1)
    BEGIN
        SELECT @c_errmsg = 'Userdefine01 has been updated.'
    END
	-- Error handling and commit/rollback
RETURN_SP:
	IF CURSOR_STATUS('LOCAL', 'update_userdefidefine01_cursor') IN (0, 1)
    BEGIN
        CLOSE update_userdefidefine01_cursor;
        DEALLOCATE update_userdefidefine01_cursor;
    END;
	IF @n_continue = 3  -- Error Occurred - Process And Return
    BEGIN
        SELECT @b_Success = 0;
        IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
        BEGIN
            ROLLBACK TRAN;
        END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @n_StartTranCnt
			BEGIN
				COMMIT TRAN
			END
		END
		execute nsp_logerror @n_err, @c_errmsg, 'isp_UpdatePalletUserdefine01'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
    END
    ELSE
    BEGIN
        SELECT @b_Success = 1;
        IF @@TRANCOUNT > @n_StartTranCnt
        BEGIN
            COMMIT TRAN;
        END;
        RETURN;
    END;
END

GO