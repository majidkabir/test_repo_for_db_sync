SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ANFUpdateEPOD                                    */
/* Creation Date: 17-Mar-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters: (Input)                                                  */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/************************************************************************/
 

CREATE PROCEDURE [dbo].[isp_ANFUpdateEPOD]
       @c_Storerkey Nvarchar(15) = 'ANF',   @c_TargetDB Nvarchar(20) = 'HKEPOD'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 	@n_continue int,
            @n_cnt int,
            @n_rowid int,
            @sql     nvarchar(4000),
            @c_SQLArgument NVARCHAR(4000)
  
  Declare @c_PODStatus  nvarchar(10), 
          @c_Rejectreasoncode nvarchar(10),
          @d_transdate  datetime,
          @c_Orderkey   nvarchar(30),
          @c_Notes      nvarchar(50),
          @n_UID        INT,
          @c_AccountID   Nvarchar(15),
          @n_RowRef     BIGINT,
          @c_ErrMsg     Nvarchar(200) = '',
          @n_ErrNo      INT = 0 


   SELECT @n_continue = 1 
	
	 IF @n_continue = 1 OR @n_continue = 2
	 BEGIN
 
      DECLARE C_ItemLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      Select   RowRef, D.key1, D.Transdate, C.short As PODStatus , ISNULL(C.long,'')   As Rejectreasoncode 
               , C.notes AS [UID], ISNULL(C.notes2,'') as AccountID 
      from dbo.docstatustrack D (NOLOCK)
      JOIN codelkup C (NOLOCK) ON  C.listname = N'SFSTSTOLFL' AND C.code  = D.Docstatus  
      and C.storerkey = D.Storerkey
      where D.storerkey = @c_Storerkey
      and D.Finalized = N'N'
      and D.Key2 = N'SFE'
      AND D.TableName = N'ORDSTSTRACK'

      OPEN C_ItemLoop  
      FETCH NEXT FROM C_ItemLoop INTO @n_RowRef, @c_Orderkey, @d_transdate, @c_PODStatus , @c_Rejectreasoncode
                              , @c_Notes, @c_AccountID
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         IF ISNUMERIC(@c_Notes) = 1
         BEGIN
            SET @n_UID = CAST(@c_Notes as INT)
         END
         ELSE 
         BEGIN
             SET @n_UID = 0
         END
 
         SELECT @sql = 'INSERT INTO  ' + @c_TargetDB + '.dbo.EPOD ( Orderkey, PODStatus, RejectReasonCode, Latitude, Longitude ' +
                     ' , locationcapturedate, deliverydate, [UID], AccountID ) ' +     
                     ' VALUES ( @c_Orderkey, @c_PODStatus, @c_Rejectreasoncode, 0.0, 0.0, @d_transdate, @d_transdate ' +
                     ' , @n_UID, @c_AccountID ) '
	 	     
      --SELECT @sql = 'UPDATE ' + @c_TargetDB + '.dbo.EPOD ' +     
      --          + ' SET PODStatus =  @c_PODStatus '     
      --          + ' , Rejectreasoncode  = @c_Rejectreasoncode'
      --          + '     , Latitude = 0.0 '     
      --          + '     , Longitude  = 0.0 ' 
      --          + '     , locationcapturedate = @d_transdate ' 
      --          + '     , deliverydate = @d_transdate ' 
      --          + ' FROM '+  @c_TargetDB + '.dbo.EPOD ' +   
      --          + ' WHERE Orderkey = @c_Orderkey '
   
               SET @c_SQLArgument = ''
               SET @c_SQLArgument = N'@c_Orderkey nvarchar(30), @c_PODStatus Nvarchar(10), @c_Rejectreasoncode nvarchar(10)  ' + 
                                      ', @d_transdate datetime, @n_UID INT, @c_AccountID  nvarchar(15) ' 

               EXEC sp_executesql @sql, @c_SQLArgument, @c_Orderkey, @c_PODStatus,  @c_Rejectreasoncode , @d_transdate
                                 , @n_UID, @c_AccountID     
               SET @n_ErrNo = @@ERROR

               IF @n_ErrNo <> 0
               BEGIN
                  SET @c_ErrMsg = 'Fail to Insert EPOD. Errno # - '+ CAST(@n_ErrNo as  nvarchar) + '(isp_ANFUpdateEPOD)' 
                  SET @n_Continue = 3
               END
               
               IF (@n_Continue = 1 OR @n_Continue = 2 )
               BEGIN
                  UPDATE dbo.Docstatustrack
                  Set Finalized = N'Y',
                     Editdate = Getdate(),
                     Editwho = Suser_Sname()
                  WHERE RowRef = @n_RowRef
               END

          FETCH NEXT FROM C_ItemLoop INTO @n_RowRef, @c_Orderkey, @d_transdate, @c_PODStatus , @c_Rejectreasoncode
                                 , @c_Notes, @c_AccountID
      END  
     
      CLOSE C_ItemLoop  
      DEALLOCATE C_ItemLoop      
         
   END      
END

GO