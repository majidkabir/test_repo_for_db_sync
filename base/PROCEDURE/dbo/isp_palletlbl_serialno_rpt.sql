SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PalletLBL_SerialNo_rpt                         */
/* Creation Date: 20 MAR 2020                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-12433 CN Logitech Pallet Level Serial No Label          */
/*                                                                      */
/* Called By: r_dw_palletlbl_serialno                                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_PalletLBL_SerialNo_rpt] (
      @c_copy           NVARCHAR(5)
   ,  @c_facility       NVARCHAR(5)
                )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

   
DECLARE  @c_LGSerialkey   NVARCHAR(5)
       , @b_Success       INT               
       , @n_Err           INT               
       , @c_ErrMsg        NVARCHAR(250) 
       , @c_LocCode       NVARCHAR(2)  = ''
       , @c_fullSerialNo  NVARCHAR(12) = ''
       , @c_YearCode      NVARCHAR(2)  = '' 
       , @c_WeekCode      NVARCHAR(2)  = ''
       , @c_lastcode      NVARCHAR(1)  = 'P'
       , @n_cnt           INT          = 1
       , @n_CurrentKey    INT          = 1
       , @n_copy          INT          = 1
       , @n_batch         INT          = 1
       , @n_lbatch        INT          = 1

      IF @c_copy = '' OR @c_facility = ''
      BEGIN
         GOTO QUIT
      END

       CREATE TABLE #LGTSerialNo ( rowid INT   IDENTITY(1,1)     PRIMARY KEY,
                            SerialNo NVARCHAR(12)) 


       SET @n_copy = CAST(@c_copy as INT)
         

      SELECT @c_YearCode = CAST(right(datepart(year,getdate()),2) as nvarchar(2))

      SELECT @c_WeekCode = CAST(datepart(week,getdate()) as nvarchar(2))

      SELECT TOP 1 @c_LocCode = C.short
      FROM CODELKUP C WITH (NOLOCK)
      where listname ='LOGILOC'
      AND code = @c_facility

      SELECT @n_CurrentKey = keycount
      FROM NCOUNTER (nolock)
      WHERE keyname = 'LGTSERIALNO'

      IF (@n_CurrentKey + @n_copy) <= 99999
      BEGIN

      EXECUTE nspg_getkey  
               'LGTSERIALNO'  
               , 5  
               , @c_LGSerialkey   OUTPUT  
               , @b_Success       OUTPUT  
               , @n_Err           OUTPUT  
               , @c_ErrMsg        OUTPUT 
               , 0    
               , @n_copy 
        --SET @n_batch = (@n_CurrentKey + @n_copy) - 99999
      END
      ELSE
      BEGIN
           SET @n_batch = 99999 - @n_CurrentKey
         SET @n_lbatch = (@n_CurrentKey + @n_copy) - 99999 

         EXECUTE nspg_getkey  
               'LGTSERIALNO'  
               , 5  
               , @c_LGSerialkey   OUTPUT  
               , @b_Success       OUTPUT  
               , @n_Err           OUTPUT  
               , @c_ErrMsg        OUTPUT  
               , 0    
               , @n_batch

            EXECUTE nspg_getkey  
               'LGTSERIALNO'  
               , 5  
               , @c_LGSerialkey   OUTPUT  
               , @b_Success       OUTPUT  
               , @n_Err           OUTPUT  
               , @c_ErrMsg        OUTPUT  
               , 0    
               , @n_lbatch

      END

      WHILE @n_copy >= 1
      BEGIN
      
           IF @n_CurrentKey > 99999
           BEGIN
             SET @n_CurrentKey = 1
           END

           SET @c_fullSerialNo = @c_YearCode + @c_WeekCode + @c_LocCode + RIGHT('00000'+CAST(ISNULL(@n_CurrentKey,1) as NVARCHAR(5)),5) + @c_lastcode

                 
              INSERT INTO #LGTSerialNo (SerialNo)
              values(@c_fullSerialNo)

            SET @n_CurrentKey =  @n_CurrentKey + 1
            SET @n_copy = @n_copy - 1
   
      END

     SELECT * FROM #LGTSerialNo
     ORDER BY 1

     DROP TABLE #LGTSerialNo

     QUIT:  

END

GO