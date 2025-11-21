SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispORD18                                           */
/* Creation Date: 20-JAN-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-21537 - [CN] LOREAL PTS Orderinfor Trigger NEW          */   
/*                                                                      */
/* Called By: isp_OrderTrigger_Wrapper from Orders Trigger              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 20-JAN-2023  CSCHONG  1.1  Devops Scripts Combine                    */
/************************************************************************/

CREATE    PROC ispORD18   
   @c_Action        NVARCHAR(10),
   @c_Storerkey     NVARCHAR(15),  
   @b_Success       INT      OUTPUT,
   @n_Err           INT      OUTPUT, 
   @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_orderkey        NVARCHAR(20),
           @c_OHStatus        NVARCHAR(10),
           @c_RecInsert       NVARCHAR(1) = 'N',
           @c_RecDelete       NVARCHAR(1) = 'N',
           @c_Option1         NVARCHAR(50) = '',
           @c_Option2         NVARCHAR(50) = '',
           @c_Option3         NVARCHAR(50) = '',
           @c_Option4         NVARCHAR(50) = '',
           @c_Option5         NVARCHAR(4000) = '',
           @c_Options         NVARCHAR(4000) = '',
           @c_trmlogkey       NVARCHAR(10),
           @c_wavekey         NVARCHAR(20),
           @c_loadkey         NVARCHAR(20) 
           
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   IF @c_Action NOT IN('UPDATE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL   
   BEGIN
       IF OBJECT_ID('tempdb..#DELETED') IS NULL 
       BEGIN
         GOTO QUIT_SP
       END
   END
   

   IF @c_Action IN('UPDATE')
   BEGIN
      IF NOT EXISTS(SELECT 1 
                    FROM #INSERTED I
                    JOIN ORDERS O (NOLOCK) ON I.Orderkey = O.Orderkey
                    WHERE I.[Status] = '3')  
      BEGIN
         IF NOT EXISTS(SELECT 1 
                    FROM #DELETED D
                    JOIN ORDERS O (NOLOCK) ON D.Orderkey = O.Orderkey
                    WHERE D.[Status] = '3')
         BEGIN
  
              GOTO QUIT_SP
         END
         ELSE
         BEGIN
           SET @c_RecDelete = 'Y'
         END
      END 
      ELSE
      BEGIN
        SET @c_RecInsert = 'Y'
      END

            IF @c_RecDelete ='Y'
            BEGIN 
                    DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                    SELECT DISTINCT D.Orderkey,D.loadkey
                    FROM #DELETED D
                    JOIN WAVE WV WITH (NOLOCK) ON WV.WaveKey=D.userdefine09 
                    JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME='PTSTYPE' AND CL.Storerkey=D.Storerkey AND CL.Code=WV.WaveType
                    WHERE D.Storerkey =@c_Storerkey
                    AND D.status='3'
                    ORDER BY D.loadkey

                  OPEN CUR_ORD

                  FETCH NEXT FROM CUR_ORD INTO @c_Orderkey,@c_loadkey

                  WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
                  BEGIN
                        

                      IF NOT EXISTS (SELECT 1 FROM Transmitlog2 WITH (NOLOCK) WHERE tablename='WSPTSLDLOG' AND key1=@c_loadkey AND key3=@c_Storerkey)
                      BEGIN
        
                             SELECT @b_success = 1      
                               EXECUTE nspg_getkey      
                               'TransmitlogKey2'      
                               , 10      
                               , @c_trmlogkey OUTPUT      
                               , @b_success   OUTPUT      
                               , @n_err       OUTPUT      
                               , @c_errmsg    OUTPUT      
             
                               IF @b_success <> 1      
                               BEGIN      
                                 SELECT @n_continue = 3      
                               END      
                               ELSE      
                               BEGIN      
                                 INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)      
                                 VALUES (@c_trmlogkey, 'WSPTSLDLOG', @c_loadkey, '', @c_Storerkey, '0', '')      
                              END 
           

                                    IF @@ERROR <> 0
                                    BEGIN
                                       SELECT @n_Continue = 3
                                       SELECT @n_Err = 39000
                                       SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Insert Transmitlog2 Failed. (ispORD18)'
                                       GOTO QUIT_SP 
                                    END
                     END

                   
                 FETCH NEXT FROM CUR_ORD INTO @c_Orderkey,@c_loadkey
                 END
                 CLOSE CUR_ORD
                 DEALLOCATE CUR_ORD


                        UPDATE WAVE
                        SET userdefine01 = 'PTS-SENT'
                        ,TrafficCop = NULL
                        ,ArchiveCop = NULL
                        FROM #DELETED D
                        JOIN WAVE WV WITH (NOLOCK) ON WV.WaveKey=D.userdefine09 
                        WHERE D.storerkey = @c_Storerkey

                        IF @@ERROR <> 0
                        BEGIN
                           SELECT @n_Continue = 3
                           SELECT @n_Err = 39010
                           SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Update Wave Failed. (ispORD18)'
                           GOTO QUIT_SP 
                        END

             END 

            IF @c_RecInsert ='Y'
            BEGIN 
                    DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                    SELECT I.Orderkey,I.loadkey
                    FROM #INSERTED I 
                    JOIN WAVE WV WITH (NOLOCK) ON WV.WaveKey=I.userdefine09 
                    JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME='PTSTYPE' AND CL.Storerkey=I.Storerkey AND CL.Code=WV.WaveType
                    WHERE I.Storerkey =@c_Storerkey
                    AND I.status='3'

                  OPEN CUR_ORD

                  FETCH NEXT FROM CUR_ORD INTO @c_Orderkey,@c_loadkey

                  WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)
                  BEGIN
                      IF NOT EXISTS (SELECT 1 FROM Transmitlog2 WITH (NOLOCK) WHERE tablename='WSPTSLDLOG' AND key1=@c_loadkey AND key3=@c_Storerkey)
                      BEGIN
        
                             SELECT @b_success = 1      
                               EXECUTE nspg_getkey      
                               'TransmitlogKey2'      
                               , 10      
                               , @c_trmlogkey OUTPUT      
                               , @b_success   OUTPUT      
                               , @n_err       OUTPUT      
                               , @c_errmsg    OUTPUT      
             
                               IF @b_success <> 1      
                               BEGIN      
                                 SELECT @n_continue = 3      
                               END      
                               ELSE      
                               BEGIN      
                                 INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)      
                                 VALUES (@c_trmlogkey, 'WSPTSLDLOG', @c_loadkey, '', @c_Storerkey, '0', '')      
                              END 
           

                                    IF @@ERROR <> 0
                                    BEGIN
                                       SELECT @n_Continue = 3
                                       SELECT @n_Err = 39000
                                       SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Insert Transmitlog2 Failed. (ispORD18)'
                                       GOTO QUIT_SP 
                                    END
                                    
                     END
                     FETCH NEXT FROM CUR_ORD INTO @c_Orderkey,@c_loadkey
                 END
                 CLOSE CUR_ORD
                 DEALLOCATE CUR_ORD

   
                     UPDATE WAVE
                     SET userdefine01 = 'PTS-SENT'
                     ,TrafficCop = NULL
                     ,ArchiveCop = NULL
                     FROM #INSERTED I
                     JOIN WAVE WV WITH (NOLOCK) ON WV.WaveKey=I.userdefine09 
                     WHERE I.storerkey = @c_Storerkey

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @n_Err = 39010
                        SELECT @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Update Wave Failed. (ispORD18)'
                        GOTO QUIT_SP 
                     END

             END 
 

   END            
                   
   QUIT_SP:
   
    IF @n_Continue=3  -- Error Occured - Process AND Return
    BEGIN
       SELECT @b_Success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispORD18'     
       --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_Success = 1
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
         COMMIT TRAN
       END
       RETURN
    END  
END  

GO