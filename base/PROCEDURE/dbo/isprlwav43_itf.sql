SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_ITF                                          */
/* Creation Date: 2021-07-22                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-22  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV43_ITF]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @n_debug       INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = 0
         , @n_Continue           INT         = 1

         , @c_Storerkey          NVARCHAR(15)= ''
         , @c_TableName          NVARCHAR(10)= 'RLWAVSOOTM' 
         
   DECLARE @t_ORDITF             TABLE 
         ( RowID                 INT                  IDENTITY(1,1)  PRIMARY KEY
         , TableName             NVARCHAR(10) NOT NULL DEFAULT('')    
         , Orderkey              NVARCHAR(10) NOT NULL DEFAULT('')
         , Storerkey             NVARCHAR(10) NOT NULL DEFAULT('')   
         , TransmitFlag          NVARCHAR(10) NOT NULL DEFAULT('')   
         , Faiclity              NVARCHAR(5)  NOT NULL DEFAULT('')                          
         )      
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   INSERT INTO @t_ORDITF
       (
         TableName
       , Orderkey
       , Storerkey
       , TransmitFlag
       , Faiclity
       )
   SELECT Tablename = @c_TableName
        , o.OrderKey
        , o.StorerKey 
        , TransmitFlag = '0'
        , o.Facility
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN ORDERS AS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey
   WHERE w.WaveKey = @c_Wavekey
   AND o.DocType = 'N'
   ORDER BY w.WaveDetailKey
   
   SELECT TOP 1 @c_Storerkey= tor.StorerKey 
   FROM @t_ORDITF AS tor
    
   IF EXISTS ( SELECT 1 FROM dbo.StorerConfig AS sc WITH (NOLOCK)    
               WHERE sc.StorerKey = @c_Storerkey   
               AND   sc.ConfigKey = @c_Tablename  
               AND   sc.SValue    = '1'
             )
   BEGIN
      INSERT INTO dbo.OTMLOG
          (   Tablename
           ,  Key1
           ,  Key2
           ,  Key3
           ,  TransmitFlag
           ,  TransmitBatch
          )
      SELECT  tor.Tablename
           ,  tor.OrderKey
           ,  Key2 = ''
           ,  tor.StorerKey 
           ,  tor.TransmitFlag 
           ,  TransmitBatch = '' 
      FROM @t_ORDITF AS tor
      LEFT OUTER JOIN dbo.OTMLOG AS o WITH (NOLOCK) ON tor.TableName = o.Tablename 
                                                   AND tor.Orderkey  = o.Key1
                                                   AND o.Key2 = '' 
                                                   AND tor.Storerkey = o.Key3
                                                   AND tor.TransmitFlag = '0'
      WHERE o.OTMLOGKey IS NULL 
      
      SET @n_err = @@ERROR  
      IF @n_err <> 0   
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 68010    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT INTO OTMLOG Table Failed. (ispRLWAV43_ITF)'   
         GOTO QUIT_SP  
      END                                                                                                                
   END  
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_ITF'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO