SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


 
/************************************************************************/
/* Stored Procedure: isp_MarkShipMBOL                                   */
/* Purpose: Update MBOL to Status 9 from backend                        */
/* Called By: SQL Schedule Job    BEJ - Backend Mark Ship MBOL (ALL)    */
/* Updates:                                                             */
/* Date         Author       Purposes                                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_MarkShipMBOL]
     @c_StorerKey NVARCHAR(15) = '%'
     ,@b_debug    INT = 0
     ,@nMinuteToSkip INT = 30 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1,
           @n_cnt             INT = 0,
           @n_err             INT = 0,
           @c_ErrMsg          NvarCHAR (255) = '',
           @n_RowCnt          INT = 0,
           @b_success         INT = 0,
           @c_MBOLKey         NVARCHAR(10) = '',
           @d_Editdate        Datetime,
           @f_status          INT = '',
           @n_StartTran       INT = 0  
        
   SET @n_StartTran = @@TRANCOUNT
   SET @n_continue=1
   SET @c_MBOLKey  = ''

   IF ISNULL(RTRIM(@c_StorerKey), '') = ''
      SET @c_StorerKey = '%'

   IF @c_StorerKey = '%'
   BEGIN
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Mbol.MbolKey, Mbol.editdate     --TLTING03
      FROM dbo.Mbol Mbol (NOLOCK)
      JOIN dbo.MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MBOL.MbolKey
      JOIN dbo.Orders O (NOLOCK) ON o.OrderKey = MD.OrderKey
      WHERE Mbol.status = '7' 
      AND Mbol.ValidatedFlag <> 'E'
      AND NOT EXISTS ( SELECT 1 FROM Codelkup C (NOLOCK)
               WHERE C.LISTNAME  = 'VALISTORER'
                        AND C.Code = O.StorerKey ) -- KH01
      ORDER BY Mbol.editdate, Mbol.MbolKey
   END
   ELSE
   BEGIN
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT  DISTINCT Mbol.MbolKey , Mbol.editdate   --TLTING03
      FROM dbo.Mbol (NOLOCK)
      JOIN dbo.MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MBOL.MbolKey
      JOIN dbo.Orders O (NOLOCK) ON o.OrderKey = MD.OrderKey
      WHERE Mbol.status = '7' 
      AND O.StorerKey = @c_StorerKey
      AND Mbol.ValidatedFlag <> 'E'
      ORDER BY Mbol.editdate, Mbol.MbolKey
   END

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_MBOLKey , @d_Editdate
    
   SELECT @f_status = @@FETCH_STATUS
   WHILE @f_status <> -1
   BEGIN 
 
      SELECT @n_continue =1
      IF @b_debug = 1
      BEGIN
      	PRINT '' 
         PRINT 'MBOLKey - ' + @c_MBOLKey  
      END
        
      IF EXISTS(SELECT 1 FROM MBOL AS m WITH(NOLOCK) WHERE m.MbolKey = @c_MBOLKey AND m.[Status] <> '9')
      BEGIN       	
         EXECUTE dbo.isp_ShipMBOL @c_MBOLKey,
                     @b_success    output,
                     @n_err        output,
                     @c_errmsg     output

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3, @c_errmsg = 'isp_ShipMBOL Fail! ' + RTrim(@c_errmsg)
         END
      END

      IF @n_continue = 1 OR @n_continue =2
      BEGIN
         IF EXISTS(SELECT 1 FROM MBOL AS m WITH(NOLOCK) WHERE m.MbolKey = @c_MBOLKey AND m.[Status] <> '9')
         BEGIN
            BEGIN TRAN             
            UPDATE MBOL WITH (ROWLOCK)
            SET MBOL.Status = '9',  -- pending ship
                FinalizeFlag = 'Y', 
                Editdate = GETDATE()
            WHERE MBOLKEY = @c_MBOLKey
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 OR @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'Fail to Update MBOL!'
               ROLLBACK TRAN
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT > 0
               BEGIN
                  COMMIT TRAN
               END
            END      
         END   
      END
   
      IF @b_debug = 1
      BEGIN
         PRINT 'Finalize Mbol - ' + @c_MBOLKey
      END 
      
      FETXH_NEXT:

      FETCH NEXT FROM CUR1 INTO @c_MBOLKey, @d_Editdate 
       
      SELECT @f_status = @@FETCH_STATUS
   END -- While

   CLOSE CUR1
   DEALLOCATE CUR1
   
   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, "isp_MarkShipMBOL"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END



GO