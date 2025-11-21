SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function fnc_GetLottableCodes                                        */
/* Creation Date: 26-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Get GTMJob                                                  */
/*        : SOS#315474 - Project Merlion - Exceed GTM Kiosk Module      */
/* Called By: Datawindow SP or PB event                                 */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/

CREATE FUNCTION [dbo].[fnc_GetLottableCodes] (@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20))      
RETURNS @tLottableCodes TABLE       
(     LottableCode      NVARCHAR(10) NOT NULL 
   ,  Lottable01label   NVARCHAR(20) NOT NULL      
   ,  Lottable02label   NVARCHAR(20) NOT NULL        
   ,  Lottable03label   NVARCHAR(20) NOT NULL       
   ,  Lottable04label   NVARCHAR(20) NOT NULL      
   ,  Lottable05label   NVARCHAR(20) NOT NULL       
   ,  Lottable06label   NVARCHAR(20) NOT NULL   
   ,  Lottable07label   NVARCHAR(20) NOT NULL  
   ,  Lottable08label   NVARCHAR(20) NOT NULL        
   ,  Lottable09label   NVARCHAR(20) NOT NULL       
   ,  Lottable10label   NVARCHAR(20) NOT NULL      
   ,  Lottable11label   NVARCHAR(20) NOT NULL       
   ,  Lottable12label   NVARCHAR(20) NOT NULL   
   ,  Lottable13label   NVARCHAR(20) NOT NULL  
   ,  Lottable14label   NVARCHAR(20) NOT NULL        
   ,  Lottable15label   NVARCHAR(20) NOT NULL 
   ,  Lottable01Code    NVARCHAR(3)  NOT NULL      
   ,  Lottable02Code    NVARCHAR(3)  NOT NULL        
   ,  Lottable03Code    NVARCHAR(3)  NOT NULL       
   ,  Lottable04Code    NVARCHAR(3)  NOT NULL      
   ,  Lottable05Code    NVARCHAR(3)  NOT NULL       
   ,  Lottable06Code    NVARCHAR(3)  NOT NULL   
   ,  Lottable07Code    NVARCHAR(3)  NOT NULL  
   ,  Lottable08Code    NVARCHAR(3)  NOT NULL        
   ,  Lottable09Code    NVARCHAR(3)  NOT NULL       
   ,  Lottable10Code    NVARCHAR(3)  NOT NULL      
   ,  Lottable11Code    NVARCHAR(3)  NOT NULL       
   ,  Lottable12Code    NVARCHAR(3)  NOT NULL   
   ,  Lottable13Code    NVARCHAR(3)  NOT NULL  
   ,  Lottable14Code    NVARCHAR(3)  NOT NULL        
   ,  Lottable15Code    NVARCHAR(3)  NOT NULL 
)      
AS      
BEGIN 
   DECLARE @n_GTMFunctionID INT

   SET @n_GTMFunctionID = -1

   IF @n_GTMFunctionID < 0 
   BEGIN
      INSERT INTO @tLottableCodes
               (  LottableCode
               ,  Lottable01label          
               ,  Lottable02label          
               ,  Lottable03label          
               ,  Lottable04label   
               ,  Lottable05label    
               ,  Lottable06label   
               ,  Lottable07label  
               ,  Lottable08label       
               ,  Lottable09label        
               ,  Lottable10label        
               ,  Lottable11label       
               ,  Lottable12label  
               ,  Lottable13label   
               ,  Lottable14label       
               ,  Lottable15label
               ,  Lottable01Code          
               ,  Lottable02Code         
               ,  Lottable03Code         
               ,  Lottable04Code         
               ,  Lottable05Code       
               ,  Lottable06Code       
               ,  Lottable07Code     
               ,  Lottable08Code           
               ,  Lottable09Code         
               ,  Lottable10Code         
               ,  Lottable11Code         
               ,  Lottable12Code   
               ,  Lottable13Code    
               ,  Lottable14Code            
               ,  Lottable15Code   
               )
         SELECT SKU.LottableCode
              , Lottable01Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN 'Lottable01Label' ELSE SKU.Lottable01Label END
              , Lottable02Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN 'Lottable02Label' ELSE SKU.Lottable02Label END
              , Lottable03Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN 'Lottable03Label' ELSE SKU.Lottable03Label END
              , Lottable04Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN 'Lottable04Label' ELSE SKU.Lottable04Label END
              , Lottable05Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN 'Lottable05Label' ELSE SKU.Lottable05Label END
              , Lottable06Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN 'Lottable06Label' ELSE SKU.Lottable06Label END
              , Lottable07Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN 'Lottable07Label' ELSE SKU.Lottable07Label END
              , Lottable08Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN 'Lottable08Label' ELSE SKU.Lottable08Label END
              , Lottable09Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN 'Lottable09Label' ELSE SKU.Lottable09Label END
              , Lottable10Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN 'Lottable10Label' ELSE SKU.Lottable10Label END
              , Lottable11Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN 'Lottable11Label' ELSE SKU.Lottable11Label END
              , Lottable12Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN 'Lottable12Label' ELSE SKU.Lottable12Label END
              , Lottable13Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN 'Lottable13Label' ELSE SKU.Lottable13Label END
              , Lottable14Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN 'Lottable14Label' ELSE SKU.Lottable14Label END
              , Lottable15Label = CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN 'Lottable15Label' ELSE SKU.Lottable15Label END
              , Lottable01Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN '0' ELSE '1' END
              , Lottable02Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN '0' ELSE '1' END
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN '0' ELSE '1' END 
              , Lottable03Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN '0' ELSE '1' END
              , Lottable04Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN '0' ELSE '1' END 
              , Lottable05Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN '0' ELSE '1' END
              , Lottable06Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN '0' ELSE '1' END
              , Lottable07Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN '0' ELSE '1' END 
              , Lottable08Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN '0' ELSE '1' END
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN '0' ELSE '1' END  
              , Lottable09Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN '0' ELSE '1' END 
              , lottable10Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN '0' ELSE '1' END 
              , lottable11Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN '0' ELSE '1' END    
              , lottable12Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN '0' ELSE '1' END  
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN '0' ELSE '1' END  
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN '0' ELSE '1' END
              , lottable13Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN '0' ELSE '1' END
              , lottable14Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN '0' ELSE '1' END 
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN '0' ELSE '1' END
              , lottable15Code = CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN '0' ELSE '1' END   
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN '0' ELSE '1' END
                               + CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN '0' ELSE '1' END      
         FROM SKU WITH (NOLOCK)
         WHERE SKU.Storerkey = @c_Storerkey
         AND   SKU.Sku = @c_Sku
   END
   ELSE
   BEGIN
      INSERT INTO @tLottableCodes
            (  LottableCode
            ,  Lottable01label          
            ,  Lottable02label          
            ,  Lottable03label          
            ,  Lottable04label   
            ,  Lottable05label    
            ,  Lottable06label   
            ,  Lottable07label  
            ,  Lottable08label       
            ,  Lottable09label        
            ,  Lottable10label        
            ,  Lottable11label       
            ,  Lottable12label  
            ,  Lottable13label   
            ,  Lottable14label       
            ,  Lottable15label
            ,  Lottable01Code          
            ,  Lottable02Code         
            ,  Lottable03Code         
            ,  Lottable04Code         
            ,  Lottable05Code       
            ,  Lottable06Code       
            ,  Lottable07Code     
            ,  Lottable08Code           
            ,  Lottable09Code         
            ,  Lottable10Code         
            ,  Lottable11Code         
            ,  Lottable12Code   
            ,  Lottable13Code    
            ,  Lottable14Code            
            ,  Lottable15Code   
            )
      SELECT SKU.LottableCode
           , Lottable01Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN 'Lottable01Label' ELSE SKU.Lottable01Label END)
           , Lottable02Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN 'Lottable02Label' ELSE SKU.Lottable02Label END)
           , Lottable03Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN 'Lottable03Label' ELSE SKU.Lottable03Label END)
           , Lottable04Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN 'Lottable04Label' ELSE SKU.Lottable04Label END)
           , Lottable05Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN 'Lottable05Label' ELSE SKU.Lottable05Label END)
           , Lottable06Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN 'Lottable06Label' ELSE SKU.Lottable06Label END)
           , Lottable07Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN 'Lottable07Label' ELSE SKU.Lottable07Label END)
           , Lottable08Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN 'Lottable08Label' ELSE SKU.Lottable08Label END)
           , Lottable09Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN 'Lottable09Label' ELSE SKU.Lottable09Label END)
           , Lottable10Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN 'Lottable10Label' ELSE SKU.Lottable10Label END)
           , Lottable11Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN 'Lottable11Label' ELSE SKU.Lottable11Label END)
           , Lottable12Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN 'Lottable12Label' ELSE SKU.Lottable12Label END)
           , Lottable13Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN 'Lottable13Label' ELSE SKU.Lottable13Label END)
           , Lottable14Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN 'Lottable14Label' ELSE SKU.Lottable14Label END)
           , Lottable15Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN 'Lottable15Label' ELSE SKU.Lottable15Label END)
           , Lottable01Code = MAX(CASE WHEN LC.lottableno = '1' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable02Code = MAX(CASE WHEN LC.lottableno = '2' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable03Code = MAX(CASE WHEN LC.lottableno = '3' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable04Code = MAX(CASE WHEN LC.lottableno = '4' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable05Code = MAX(CASE WHEN LC.lottableno = '5' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable06Code = MAX(CASE WHEN LC.lottableno = '6' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable07Code = MAX(CASE WHEN LC.lottableno = '7' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable08Code = MAX(CASE WHEN LC.lottableno = '8' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable09Code = MAX(CASE WHEN LC.lottableno = '9' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable10Code = MAX(CASE WHEN LC.lottableno = '10'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable11Code = MAX(CASE WHEN LC.lottableno = '11'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable12Code = MAX(CASE WHEN LC.lottableno = '12'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)  
           , lottable13Code = MAX(CASE WHEN LC.lottableno = '13'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable14Code = MAX(CASE WHEN LC.lottableno = '14'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable15Code = MAX(CASE WHEN LC.lottableno = '15'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)     
      FROM SKU WITH (NOLOCK)
      JOIN [RDT].[rdtLottableCode] LC WITH (NOLOCK) ON (SKU.LottableCode = LC.LottableCode)
      WHERE SKU.Storerkey = @c_Storerkey
      AND   SKU.Sku = @c_Sku
      AND   LC.FUNCTION_ID = @n_GTMFunctionID --538
      GROUP BY SKU.LottableCode

      IF NOT EXISTS (SELECT 1 
                     FROM @tLottableCodes)
      BEGIN
         INSERT INTO @tLottableCodes
               (  LottableCode
               ,  Lottable01label          
               ,  Lottable02label          
               ,  Lottable03label          
               ,  Lottable04label   
               ,  Lottable05label    
               ,  Lottable06label   
               ,  Lottable07label  
               ,  Lottable08label       
               ,  Lottable09label        
               ,  Lottable10label        
               ,  Lottable11label       
               ,  Lottable12label  
               ,  Lottable13label   
               ,  Lottable14label       
               ,  Lottable15label
               ,  Lottable01Code          
               ,  Lottable02Code         
               ,  Lottable03Code         
               ,  Lottable04Code         
               ,  Lottable05Code       
               ,  Lottable06Code       
               ,  Lottable07Code     
               ,  Lottable08Code           
               ,  Lottable09Code         
               ,  Lottable10Code         
               ,  Lottable11Code         
               ,  Lottable12Code   
               ,  Lottable13Code    
               ,  Lottable14Code            
               ,  Lottable15Code   
               )
         SELECT SKU.LottableCode
           , Lottable01Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable01Label),'') = '' THEN 'Lottable01Label' ELSE SKU.Lottable01Label END)
           , Lottable02Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable02Label),'') = '' THEN 'Lottable02Label' ELSE SKU.Lottable02Label END)
           , Lottable03Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable03Label),'') = '' THEN 'Lottable03Label' ELSE SKU.Lottable03Label END)
           , Lottable04Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable04Label),'') = '' THEN 'Lottable04Label' ELSE SKU.Lottable04Label END)
           , Lottable05Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable05Label),'') = '' THEN 'Lottable05Label' ELSE SKU.Lottable05Label END)
           , Lottable06Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable06Label),'') = '' THEN 'Lottable06Label' ELSE SKU.Lottable06Label END)
           , Lottable07Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable07Label),'') = '' THEN 'Lottable07Label' ELSE SKU.Lottable07Label END)
           , Lottable08Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable08Label),'') = '' THEN 'Lottable08Label' ELSE SKU.Lottable08Label END)
           , Lottable09Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable09Label),'') = '' THEN 'Lottable09Label' ELSE SKU.Lottable09Label END)
           , Lottable10Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable10Label),'') = '' THEN 'Lottable10Label' ELSE SKU.Lottable10Label END)
           , Lottable11Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable11Label),'') = '' THEN 'Lottable11Label' ELSE SKU.Lottable11Label END)
           , Lottable12Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable12Label),'') = '' THEN 'Lottable12Label' ELSE SKU.Lottable12Label END)
           , Lottable13Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable13Label),'') = '' THEN 'Lottable13Label' ELSE SKU.Lottable13Label END)
           , Lottable14Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable14Label),'') = '' THEN 'Lottable14Label' ELSE SKU.Lottable14Label END)
           , Lottable15Label = MAX(CASE WHEN ISNULL(RTRIM(SKU.Lottable15Label),'') = '' THEN 'Lottable15Label' ELSE SKU.Lottable15Label END)
           , Lottable01Code = MAX(CASE WHEN LC.lottableno = '1' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable02Code = MAX(CASE WHEN LC.lottableno = '2' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable03Code = MAX(CASE WHEN LC.lottableno = '3' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable04Code = MAX(CASE WHEN LC.lottableno = '4' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable05Code = MAX(CASE WHEN LC.lottableno = '5' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable06Code = MAX(CASE WHEN LC.lottableno = '6' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable07Code = MAX(CASE WHEN LC.lottableno = '7' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable08Code = MAX(CASE WHEN LC.lottableno = '8' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , Lottable09Code = MAX(CASE WHEN LC.lottableno = '9' THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable10Code = MAX(CASE WHEN LC.lottableno = '10'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable11Code = MAX(CASE WHEN LC.lottableno = '11'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable12Code = MAX(CASE WHEN LC.lottableno = '12'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)  
           , lottable13Code = MAX(CASE WHEN LC.lottableno = '13'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable14Code = MAX(CASE WHEN LC.lottableno = '14'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)
           , lottable15Code = MAX(CASE WHEN LC.lottableno = '15'THEN (LC.visible + LC.Editable + LC.Required) ELSE '' END)       
         FROM SKU WITH (NOLOCK)
         LEFT JOIN [RDT].[rdtLottableCode] LC WITH (NOLOCK) ON (SKU.LottableCode = LC.LottableCode)
                                                            
         WHERE SKU.Storerkey = @c_Storerkey
         AND   SKU.Sku = @c_Sku
         AND(LC.FUNCTION_ID = 0)
         GROUP BY SKU.LottableCode
      END
   END
   RETURN 
END

GO