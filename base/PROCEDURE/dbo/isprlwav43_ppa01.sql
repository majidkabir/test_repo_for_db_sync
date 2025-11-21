SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_PPA01                                        */
/* Creation Date: 2021-07-22                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        : PPA BY Orderkey                                             */
/* Called By: ispRLWAV43                                                */
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
CREATE PROC [dbo].[ispRLWAV43_PPA01]
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

         , @c_Facility           NVARCHAR(5) = ''
         , @c_Storerkey          NVARCHAR(15)= ''
         , @c_Release_Opt5       NVARCHAR(4000)= ''
         
         , @c_PPA100Export       NVARCHAR(10)= ''
         , @n_NoOfOrd_Export     INT         = 0 
         , @n_NoOfOrd_Local      INT         = 0          
         , @n_NofPPA             INT         = 0
         , @n_PPAPctg            FLOAT       = 0.00     
                  
   DECLARE @t_PPA_WIP            TABLE 
         ( RowID                 INT                     IDENTITY(1,1)  PRIMARY KEY
         , Facility              NVARCHAR(5)  NOT NULL   DEFAULT('')
         , Storerkey             NVARCHAR(15) NOT NULL   DEFAULT('')        
         , Orderkey              NVARCHAR(10) NOT NULL   DEFAULT('')
         , Export_Ord            NVARCHAR(1)  NOT NULL   DEFAULT('N')
         , PickSlipNo            NVARCHAR(10) NOT NULL   DEFAULT('')    
         ) 
         
   DECLARE @t_PPA_CTN            TABLE 
         ( RowID                 INT                     IDENTITY(1,1)  PRIMARY KEY
         , PickSlipNo            NVARCHAR(10) NOT NULL   DEFAULT('')    
         , Orderkey              NVARCHAR(10) NOT NULL   DEFAULT('')
         )            
   
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   INSERT INTO @t_PPA_WIP
       (
         Facility
       , Storerkey
       , Orderkey
       , Export_Ord
       , PickSlipNo
       )
   SELECT
         o.Facility
       , o.Storerkey
       , o.Orderkey
       , Export_Ord = CASE WHEN o.C_Country = s.Country THEN 'N' ELSE 'Y' END
       , ph.PickSlipNo
   FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)
   JOIN ORDERS AS o WITH (NOLOCK) ON w.Orderkey = o.Orderkey
   JOIN STORER AS s WITH (NOLOCK) ON o.StorerKey= s.StorerKey
   JOIN dbo.PackHeader AS ph WITH (NOLOCK) ON ph.OrderKey = o.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   AND o.DocType = 'N'
   ORDER BY w.WaveDetailKey

   IF NOT EXISTS ( SELECT 1 FROM @t_PPA_WIP AS tpw ) 
   BEGIN
      GOTO QUIT_SP
   END
   
   SELECT TOP 1 @c_Storerkey= tpw.StorerKey 
   FROM @t_PPA_WIP AS tpw

   EXEC nspGetRight          
      @c_Facility  = @c_Facility          
   ,  @c_StorerKey = @c_StorerKey         
   ,  @c_sku       = NULL          
   ,  @c_ConfigKey = 'ReleaseWave_SP'         
   ,  @b_Success   = @b_Success        OUTPUT          
   ,  @c_authority = ''           
   ,  @n_err       = @n_err            OUTPUT          
   ,  @c_errmsg    = @c_errmsg         OUTPUT   
   ,  @c_OPtion5   = @c_Release_Opt5   OUTPUT 
       
   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   SET @n_PPAPctg = 0.00
   SELECT @n_PPAPctg = dbo.fnc_GetParamValueFromString('@n_PPAPctg', @c_Release_Opt5, @n_PPAPctg) 

   SET @c_PPA100Export = 'N'
   SELECT @c_PPA100Export = dbo.fnc_GetParamValueFromString('@c_PPA100Export', @c_Release_Opt5, @c_PPA100Export) 
   
   SELECT @n_NoOfOrd_Export = ISNULL(SUM(CASE WHEN tpw.Export_Ord = 'Y' THEN 1 ELSE 0 END),0)
         ,@n_NoOfOrd_Local  = ISNULL(SUM(CASE WHEN tpw.Export_Ord = 'Y' THEN 0 ELSE 1 END),0)
   FROM @t_PPA_WIP AS tpw
   
   IF @c_PPA100Export = 'Y'
   BEGIN
      INSERT INTO @t_PPA_CTN ( PickSlipNo, Orderkey )
      SELECT tpw.PickSlipNo, tpw.Orderkey
      FROM @t_PPA_WIP AS tpw
      WHERE tpw.Export_Ord = 'Y'
      
      SET @n_NofPPA = @n_NoOfOrd_Local
   END
   ELSE 
   BEGIN
      SET @n_NofPPA = @n_NoOfOrd_Local + @n_NoOfOrd_Export
   
      IF @n_PPAPctg = 0.00
      BEGIN
         GOTO QUIT_SP
      END
   END
   SET @n_NofPPA = CEILING( @n_NofPPA * ( @n_PPAPctg / 100.00 ) )  
      
   INSERT INTO @t_PPA_CTN ( PickSlipNo, Orderkey )
   SELECT TOP (@n_NofPPA) 
         tpw.PickSlipNo, tpw.Orderkey
   FROM @t_PPA_WIP AS tpw
   WHERE NOT EXISTS (   SELECT 1
                        FROM @t_PPA_CTN AS tpc
                        WHERE tpc.PickSlipNo = tpw.PickSlipNo
                        AND tpc.Orderkey = tpw.Orderkey
                    )
   ORDER BY NEWID()
   
   IF NOT EXISTS ( SELECT 1 FROM @t_PPA_CTN AS tpc ) 
   BEGIN
      GOTO QUIT_SP
   END
   
   ;WITH updpi ( PickSlipNo, CartonNo ) AS
   (  SELECT PI.PickSlipNo, PI.CartonNo
      FROM @t_PPA_CTN AS tpc
      JOIN dbo.PackInfo AS PI ON PI.PickSlipNo = tpc.PickSlipNo 
   )
   
   UPDATE PI WITH (ROWLOCK)
   SET pi.RefNo = 'PPA'
      ,pi.EditWho = SUSER_SNAME()
      ,PI.EditDate= GETDATE()
      ,pi.TrafficCop = NULL
   FROM updpi AS upi
   JOIN dbo.PackInfo AS PI ON PI.PickSlipNo = upi.PickSlipNo AND PI.CartonNo = upi.CartonNo
      
   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 68010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PACKINFO Table Failed. (ispRLWAV43_PPA01)'   
      GOTO QUIT_SP  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_PPA01'
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